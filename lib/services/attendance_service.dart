import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/offline_service.dart';

class AttendanceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final OfflineService _offlineService = OfflineService();

  // Configure how long a QR session remains valid (lecture duration window)
  static const int attendanceWindowMinutes = 90;

  // Improved data structure:
  // - attendance/{subjectCode}/records/{recordId} - for subject-wise attendance
  // - students/{studentEmail}/attendance/{recordId} - for student-wise attendance 
  // - teachers/{teacherEmail}/attendance/{recordId} - for teacher-wise attendance
  // - daily_attendance/{date}/records/{recordId} - for date-wise attendance

  // Mark attendance for a student with improved structure
  static Future<bool> markAttendance({
    required String studentEmail,
    required String studentName,
    required String subjectCode,
    String? teacherEmail,
    String? teacherName,
  }) async {
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final timeStr = DateFormat('HH:mm').format(now);
      final recordId = '${studentEmail.split('@')[0]}_${subjectCode}_$dateStr';

      // Get current user from Firebase Auth to determine teacher info
      String currentTeacherEmail = teacherEmail ?? '';
      String currentTeacherName = teacherName ?? 'System';
      String subjectName = subjectCode;

      // Get subject information
      final subjectDoc = await _firestore
          .collection('subjects')
          .doc(subjectCode)
          .get();

      if (subjectDoc.exists) {
        final data = subjectDoc.data() as Map<String, dynamic>;
        subjectName = data['name'] ?? subjectCode;
        currentTeacherEmail = data['teacherEmail'] ?? currentTeacherEmail;
        
        // Get teacher name if not provided
        if (currentTeacherName == 'System' && currentTeacherEmail.isNotEmpty) {
          final teacherDoc = await _firestore
              .collection('teachers')
              .doc(currentTeacherEmail)
              .get();
          if (teacherDoc.exists) {
            currentTeacherName = teacherDoc.data()?['fullName'] ?? 'Teacher';
          }
        }
      }

      // Check for duplicate attendance using the new structure
      final existingAttendance = await _firestore
          .collection('attendance')
          .doc(subjectCode)
          .collection('records')
          .doc(recordId)
          .get();

      if (existingAttendance.exists) {
        throw Exception('Attendance already marked for $subjectName today');
      }

      // Create comprehensive attendance record
      final attendanceData = {
        'recordId': recordId,
        'studentEmail': studentEmail,
        'studentName': studentName,
        'teacherEmail': currentTeacherEmail,
        'teacherName': currentTeacherName,
        'subject': subjectName,
        'subjectCode': subjectCode,
        'date': dateStr,
        'time': timeStr,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': now.millisecondsSinceEpoch,
        'academicYear': _getAcademicYear(now),
        'semester': _getCurrentSemester(now),
        'status': 'present',
      };

      // Store in multiple collections for efficient querying
      try {
        final batch = _firestore.batch();
        
        // 1. Subject-wise attendance
        batch.set(
          _firestore.collection('attendance').doc(subjectCode).collection('records').doc(recordId),
          attendanceData
        );
        
        // 2. Student-wise attendance
        batch.set(
          _firestore.collection('students').doc(studentEmail).collection('attendance').doc(recordId),
          attendanceData
        );
        
        // 3. Teacher-wise attendance
        batch.set(
          _firestore.collection('teachers').doc(currentTeacherEmail).collection('attendance').doc(recordId),
          attendanceData
        );
        
        // 4. Daily attendance for reports
        batch.set(
          _firestore.collection('daily_attendance').doc(dateStr).collection('records').doc(recordId),
          attendanceData
        );
        
        // 5. Update student's subject enrollment and stats
        batch.set(
          _firestore.collection('students').doc(studentEmail).collection('subjects').doc(subjectCode),
          {
            'subjectCode': subjectCode,
            'subjectName': subjectName,
            'teacherEmail': currentTeacherEmail,
            'teacherName': currentTeacherName,
            'lastAttendance': dateStr,
            'totalAttendance': FieldValue.increment(1),
          },
          SetOptions(merge: true)
        );
        
        await batch.commit();
        print('Attendance marked successfully in improved structure');
        return true;
        
      } catch (e) {
        // Store offline if network error
        final offlineOperation = OfflineOperation(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: OperationType.create,
          collection: 'attendance_unified',
          documentId: recordId,
          data: attendanceData,
          timestamp: DateTime.now(),
        );
        
        await _offlineService.storeOfflineOperation(offlineOperation);
        print('Attendance stored offline: $e');
        return true;
      }

    } catch (e) {
      print('Error marking attendance: $e');
      rethrow;
    }
  }
  
  // Generate QR code data with teacher context
  static Future<Map<String, String>> generateQRCodeData({
    required String teacherEmail,
    required String subjectCode,
  }) async {
    try {
      final now = DateTime.now();
      final teacherDoc = await _firestore
          .collection('teachers')
          .doc(teacherEmail)
          .get();
      
      String teacherName = 'Teacher';
      if (teacherDoc.exists) {
        teacherName = teacherDoc.data()?['fullName'] ?? 'Teacher';
      }
      
      // Store QR session information for validation
      await _firestore.collection('qr_sessions').doc('${subjectCode}_${DateFormat('yyyy-MM-dd').format(now)}').set({
        'subjectCode': subjectCode,
        'teacherEmail': teacherEmail,
        'teacherName': teacherName,
        'generatedAt': FieldValue.serverTimestamp(),
        'validUntil': Timestamp.fromDate(now.add(Duration(minutes: attendanceWindowMinutes))),
        'isActive': true,
      });
      
      return {
        'qrCode': subjectCode,
        'teacherEmail': teacherEmail,
        'teacherName': teacherName,
        'subject': subjectCode,
      };
      
    } catch (e) {
      print('Error generating QR code data: $e');
      return {
        'qrCode': subjectCode,
        'teacherEmail': teacherEmail ?? '',
        'teacherName': 'Teacher',
        'subject': subjectCode,
      };
    }
  }
  
  // Enhanced mark attendance with teacher context from QR session
  static Future<bool> markAttendanceWithQR({
    required String studentEmail,
    required String studentName,
    required String qrCode,
  }) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // Get QR session information
      final qrSession = await _firestore
          .collection('qr_sessions')
          .doc('${qrCode}_$today')
          .get();
      
      String teacherEmail = '';
      String teacherName = 'Unknown Teacher';
      
      if (qrSession.exists) {
        final sessionData = qrSession.data() as Map<String, dynamic>;
        teacherEmail = sessionData['teacherEmail'] ?? '';
        teacherName = sessionData['teacherName'] ?? 'Unknown Teacher';
        
        // Check if session is still valid
        final validUntil = sessionData['validUntil'] as Timestamp?;
        if (validUntil != null && validUntil.toDate().isBefore(DateTime.now())) {
          throw Exception('QR code has expired. Please ask teacher to generate a new one.');
        }
        
        if (sessionData['isActive'] != true) {
          throw Exception('QR session is no longer active.');
        }
      }
      
      // Mark attendance with teacher context
      return await markAttendance(
        studentEmail: studentEmail,
        studentName: studentName,
        subjectCode: qrCode,
        teacherEmail: teacherEmail,
        teacherName: teacherName,
      );
      
    } catch (e) {
      print('Error marking attendance with QR: $e');
      rethrow;
    }
  }
  
  // Helper function to get academic year
  static String _getAcademicYear(DateTime date) {
    final year = date.year;
    final month = date.month;
    
    // Academic year starts from July
    if (month >= 7) {
      return '$year-${year + 1}';
    } else {
      return '${year - 1}-$year';
    }
  }
  
  // Helper function to get current semester
  static String _getCurrentSemester(DateTime date) {
    final month = date.month;
    
    // Semester 1: July-December, Semester 2: January-June
    if (month >= 7) {
      return 'Semester 1';
    } else {
      return 'Semester 2';
    }
  }

  // Get attendance for a student using improved structure
  static Future<List<Map<String, dynamic>>> getStudentAttendance({
    required String studentEmail,
    DateTime? startDate,
    DateTime? endDate,
    String? subjectCode,
  }) async {
    try {
      startDate ??= DateTime.now().subtract(Duration(days: 30));
      endDate ??= DateTime.now();

      // Normalize to inclusive range
      final startMs = DateTime(startDate.year, startDate.month, startDate.day).millisecondsSinceEpoch;
      final endMs = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999).millisecondsSinceEpoch;

      // Query from student's attendance subcollection using createdAt for efficient single-field indexing
      Query query = _firestore
          .collection('students')
          .doc(studentEmail)
          .collection('attendance')
          .where('createdAt', isGreaterThanOrEqualTo: startMs)
          .where('createdAt', isLessThanOrEqualTo: endMs)
          .orderBy('createdAt', descending: true);
      
      // Note: Avoid composite index by not filtering on subjectCode in Firestore; filter client-side instead
      final snapshot = await query.get();

      final all = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      if (subjectCode != null) {
        return all.where((e) => e['subjectCode'] == subjectCode).toList();
      }
      return all;

    } catch (e) {
      print('Error getting student attendance: $e');
      return [];
    }
  }

  // Get attendance for a teacher's subject using improved structure
  static Future<List<Map<String, dynamic>>> getSubjectAttendance({
    String? teacherEmail,
    String? subjectCode,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      List<Map<String, dynamic>> results = [];
      
      if (subjectCode != null) {
        // Query by subject - efficient and avoids composite index by using createdAt
        Query query = _firestore
            .collection('attendance')
            .doc(subjectCode)
            .collection('records');
            
        // Build createdAt range
        if (date != null) {
          final start = DateTime(date.year, date.month, date.day);
          final end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
          query = query
              .where('createdAt', isGreaterThanOrEqualTo: start.millisecondsSinceEpoch)
              .where('createdAt', isLessThanOrEqualTo: end.millisecondsSinceEpoch);
        } else if (startDate != null || endDate != null) {
          final start = startDate != null
              ? DateTime(startDate.year, startDate.month, startDate.day)
              : DateTime(1970);
          final end = endDate != null
              ? DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999)
              : DateTime.now();
          query = query
              .where('createdAt', isGreaterThanOrEqualTo: start.millisecondsSinceEpoch)
              .where('createdAt', isLessThanOrEqualTo: end.millisecondsSinceEpoch);
        }
        
        final snapshot = await query.orderBy('createdAt', descending: true).get();
        results = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
        
        // Filter by teacher if specified
        if (teacherEmail != null) {
          results = results.where((record) => record['teacherEmail'] == teacherEmail).toList();
        }
        
      } else if (teacherEmail != null) {
        // Query by teacher - for teacher's dashboard
        Query query = _firestore
            .collection('teachers')
            .doc(teacherEmail)
            .collection('attendance');
            
        // Add date filters
        if (date != null) {
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          query = query.where('date', isEqualTo: dateStr);
        } else if (startDate != null || endDate != null) {
          if (startDate != null) {
            query = query.where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startDate));
          }
          if (endDate != null) {
            query = query.where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endDate));
          }
        }
        
        final snapshot = await query.orderBy('timestamp', descending: true).get();
        results = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
        
      } else {
        throw Exception('Either teacherEmail or subjectCode must be provided');
      }
      
      return results;

    } catch (e) {
      print('Error getting subject attendance: $e');
      
      // Fallback to old unified collection
      try {
        Query fallbackQuery = _firestore.collection('attendance_unified');
        
        if (teacherEmail != null) {
          fallbackQuery = fallbackQuery.where('teacherEmail', isEqualTo: teacherEmail);
        }
        if (subjectCode != null) {
          fallbackQuery = fallbackQuery.where('subjectCode', isEqualTo: subjectCode);
        }
        if (date != null) {
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          fallbackQuery = fallbackQuery.where('date', isEqualTo: dateStr);
        }
        
        final snapshot = await fallbackQuery.orderBy('timestamp', descending: true).get();
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
      } catch (fallbackError) {
        print('Error with fallback query: $fallbackError');
        return [];
      }
    }
  }

  // Get today's attendance status for a student (new structure)
  static Future<Map<String, dynamic>?> getTodayAttendanceStatus({
    required String studentEmail,
    required String subject,
  }) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final query = await _firestore
          .collection('students')
          .doc(studentEmail)
          .collection('attendance')
          .where('subject', isEqualTo: subject)
          .where('date', isEqualTo: today)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        data['id'] = query.docs.first.id;
        return data;
      }
      return null;

    } catch (e) {
      print('Error getting today attendance status: $e');
      return null;
    }
  }

  // Get attendance statistics (aligned with new structure)
  static Future<Map<String, int>> getAttendanceStats({
    String? teacherEmail,
    String? studentEmail,
    String? subject,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      startDate ??= DateTime.now().subtract(Duration(days: 30));
      endDate ??= DateTime.now();

      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);

      QuerySnapshot snapshot;

      if (studentEmail != null && studentEmail.isNotEmpty) {
        // Query student's attendance subcollection
        Query q = _firestore
            .collection('students')
            .doc(studentEmail)
            .collection('attendance')
            .where('date', isGreaterThanOrEqualTo: startDateStr)
            .where('date', isLessThanOrEqualTo: endDateStr);
        if (subject != null && subject.isNotEmpty) {
          q = q.where('subject', isEqualTo: subject);
        }
        snapshot = await q.get();
      } else {
        // Aggregate from subject records across all subjects
        Query q = _firestore
            .collectionGroup('records')
            .where('date', isGreaterThanOrEqualTo: startDateStr)
            .where('date', isLessThanOrEqualTo: endDateStr);
        if (teacherEmail != null && teacherEmail.isNotEmpty) {
          q = q.where('teacherEmail', isEqualTo: teacherEmail);
        }
        if (subject != null && subject.isNotEmpty) {
          // Match by display subject; if you prefer subjectCode, filter by subjectCode instead
          q = q.where('subject', isEqualTo: subject);
        }
        snapshot = await q.get();
      }
      
      final uniqueStudents = <String>{};
      final uniqueDates = <String>{};
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        uniqueStudents.add(data['studentEmail'] ?? '');
        uniqueDates.add(data['date'] ?? '');
      }

      return {
        'totalAttendance': snapshot.docs.length,
        'uniqueStudents': uniqueStudents.length,
        'uniqueDays': uniqueDates.length,
      };

    } catch (e) {
      print('Error getting attendance stats: $e');
      return {
        'totalAttendance': 0,
        'uniqueStudents': 0,
        'uniqueDays': 0,
      };
    }
  }

  // Create or update subject
  static Future<bool> createSubject({
    required String code,
    required String name,
    required String teacherEmail,
  }) async {
    try {
      await _firestore.collection('subjects').doc(code).set({
        'name': name,
        'code': code,
        'teacherEmail': teacherEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error creating subject: $e');
      return false;
    }
  }

  // Get subjects for a teacher
  static Future<List<Map<String, dynamic>>> getTeacherSubjects({
    required String teacherEmail,
  }) async {
    try {
      final query = await _firestore
          .collection('subjects')
          .where('teacherEmail', isEqualTo: teacherEmail)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

    } catch (e) {
      print('Error getting teacher subjects: $e');
      return [];
    }
  }

  // Get all subjects for student enrollment
  static Future<List<Map<String, dynamic>>> getAllSubjects() async {
    try {
      final query = await _firestore
          .collection('subjects')
          .orderBy('name')
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

    } catch (e) {
      print('Error getting all subjects: $e');
      return [];
    }
  }

  // Enroll student in subjects
  static Future<bool> enrollStudent({
    required String studentEmail,
    required List<String> subjectCodes,
  }) async {
    try {
      await _firestore.collection('student_enrollments').doc(studentEmail).set({
        'studentEmail': studentEmail,
        'subjects': subjectCodes,
        'enrolledAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error enrolling student: $e');
      return false;
    }
  }

  // Get student enrolled subjects
  static Future<List<String>> getStudentSubjects({
    required String studentEmail,
  }) async {
    try {
      final doc = await _firestore
          .collection('student_enrollments')
          .doc(studentEmail)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return List<String>.from(data['subjects'] ?? []);
      }
      return [];

    } catch (e) {
      print('Error getting student subjects: $e');
      return [];
    }
  }
}