import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';
import '../utils/validators.dart';

class UserManagementService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create teacher account
  static Future<bool> createTeacher({
    required String email,
    required String password,
    required String fullName,
    required String subject,
  }) async {
    try {
      // Validate input
      final emailError = Validators.validateEmail(email);
      final passwordError = Validators.validatePassword(password);
      final nameError = Validators.validateFullName(fullName);
      final subjectError = Validators.validateSubject(subject);

      if (emailError != null) throw Exception(emailError);
      if (passwordError != null) throw Exception(passwordError);
      if (nameError != null) throw Exception(nameError);
      if (subjectError != null) throw Exception(subjectError);

      // Sanitize data
      final sanitizedEmail = Validators.sanitizeEmail(email);
      final sanitizedName = Validators.sanitizeName(fullName);
      final sanitizedSubject = Validators.sanitizeText(subject);

      // Create secondary app for user creation
      FirebaseApp? secondaryApp;
      try {
        secondaryApp = Firebase.app('secondary');
      } catch (e) {
        secondaryApp = await Firebase.initializeApp(
          name: 'secondary',
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // Create user account
      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: sanitizedEmail,
        password: password,
      );

      // Store teacher data in Firestore
      await _firestore.collection('teachers').doc(sanitizedEmail).set({
        'fullName': sanitizedName,
        'email': sanitizedEmail,
        'subject': sanitizedSubject,
        'createdAt': FieldValue.serverTimestamp(),
        'password': password, // Store for deletion purposes
        'uid': userCredential.user?.uid,
      });

      // Create subject entry
      await _firestore.collection('subjects').doc(sanitizedSubject.toUpperCase()).set({
        'name': sanitizedSubject,
        'code': sanitizedSubject.toUpperCase(),
        'teacherEmail': sanitizedEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sign out from secondary app
      await secondaryAuth.signOut();

      return true;
    } catch (e) {
      print('Error creating teacher: $e');
      rethrow;
    }
  }

  // Create student account
  static Future<bool> createStudent({
    required String email,
    required String password,
    required String fullName,
    required List<String> subjects,
  }) async {
    try {
      // Validate input
      final emailError = Validators.validateEmail(email);
      final passwordError = Validators.validatePassword(password);
      final nameError = Validators.validateFullName(fullName);

      if (emailError != null) throw Exception(emailError);
      if (passwordError != null) throw Exception(passwordError);
      if (nameError != null) throw Exception(nameError);

      // Sanitize data
      final sanitizedEmail = Validators.sanitizeEmail(email);
      final sanitizedName = Validators.sanitizeName(fullName);

      // Create secondary app for user creation
      FirebaseApp? secondaryApp;
      try {
        secondaryApp = Firebase.app('secondary');
      } catch (e) {
        secondaryApp = await Firebase.initializeApp(
          name: 'secondary',
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // Create user account
      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: sanitizedEmail,
        password: password,
      );

      // Store student data in Firestore
      await _firestore.collection('students').doc(sanitizedEmail).set({
        'fullName': sanitizedName,
        'email': sanitizedEmail,
        'subjects': subjects,
        'createdAt': FieldValue.serverTimestamp(),
        'password': password, // Store for deletion purposes
        'uid': userCredential.user?.uid,
      });

      // Enroll student in subjects
      await _firestore.collection('student_enrollments').doc(sanitizedEmail).set({
        'studentEmail': sanitizedEmail,
        'subjects': subjects,
        'enrolledAt': FieldValue.serverTimestamp(),
      });

      // Sign out from secondary app
      await secondaryAuth.signOut();

      return true;
    } catch (e) {
      print('Error creating student: $e');
      rethrow;
    }
  }

  // Get all teachers
  static Future<List<Map<String, dynamic>>> getAllTeachers() async {
    try {
      final snapshot = await _firestore
          .collection('teachers')
          .orderBy('fullName')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting teachers: $e');
      return [];
    }
  }

  // Get all students
  static Future<List<Map<String, dynamic>>> getAllStudents() async {
    try {
      final snapshot = await _firestore
          .collection('students')
          .orderBy('fullName')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting students: $e');
      return [];
    }
  }

  // Delete teacher
  static Future<bool> deleteTeacher(String email) async {
    try {
      // Get teacher data first
      final teacherDoc = await _firestore.collection('teachers').doc(email).get();
      if (!teacherDoc.exists) {
        throw Exception('Teacher not found');
      }

      final teacherData = teacherDoc.data() as Map<String, dynamic>;
      final password = (teacherData['authPassword'] as String?) ?? (teacherData['password'] as String?);

      // 1) For every subject owned by this teacher, cascade delete:
      final subjectsQuery = await _firestore
          .collection('subjects')
          .where('teacherEmail', isEqualTo: email)
          .get();

      for (var subjectDoc in subjectsQuery.docs) {
        final subjectCode = subjectDoc.id;

        // a) Delete all attendance records under attendance/{subject}/records and their mirrors
        final recordsSnap = await _firestore
            .collection('attendance')
            .doc(subjectCode)
            .collection('records')
            .get();
        for (final rec in recordsSnap.docs) {
          final recData = rec.data() as Map<String, dynamic>;
          final recordId = (recData['recordId'] as String?) ?? rec.id;
          final studentEmail = recData['studentEmail'] as String?;
          final dateStr = recData['date'] as String?;

          // Delete student's copy
          if (studentEmail != null && studentEmail.isNotEmpty) {
            await _firestore
                .collection('students')
                .doc(studentEmail)
                .collection('attendance')
                .doc(recordId)
                .delete()
                .catchError((_) {});
          }

          // Delete teacher's copy
          await _firestore
              .collection('teachers')
              .doc(email)
              .collection('attendance')
              .doc(recordId)
              .delete()
              .catchError((_) {});

          // Delete daily mirror
          if (dateStr != null && dateStr.isNotEmpty) {
            await _firestore
                .collection('daily_attendance')
                .doc(dateStr)
                .collection('records')
                .doc(recordId)
                .delete()
                .catchError((_) {});
          }

          // Finally delete subject record
          await rec.reference.delete().catchError((_) {});
        }

        // b) Remove roster mirrors and student subject refs
        final rosterSnap = await _firestore
            .collection('subject_enrollments')
            .doc(subjectCode)
            .collection('students')
            .get();
        for (final r in rosterSnap.docs) {
          final rData = r.data() as Map<String, dynamic>;
          final studentEmail = rData['studentEmail'] as String? ?? r.id;

          // Remove student->subject subdoc
          await _firestore
              .collection('students')
              .doc(studentEmail)
              .collection('subjects')
              .doc(subjectCode)
              .delete()
              .catchError((_) {});

          // Update student arrays and legacy enrollment view
          await _firestore.collection('students').doc(studentEmail).set({
            'subjects': FieldValue.arrayRemove([subjectCode])
          }, SetOptions(merge: true));
          await _firestore.collection('student_enrollments').doc(studentEmail).set({
            'studentEmail': studentEmail,
            'subjects': FieldValue.arrayRemove([subjectCode])
          }, SetOptions(merge: true));

          // Delete roster doc
          await r.reference.delete().catchError((_) {});
        }
        // Remove the subject_enrollments container doc if present
        await _firestore.collection('subject_enrollments').doc(subjectCode).delete().catchError((_) {});

        // c) Delete the subject document
        await subjectDoc.reference.delete().catchError((_) {});
      }

      // 2) Delete all teacher-specific attendance subcollection
      final tAttSnap = await _firestore
          .collection('teachers')
          .doc(email)
          .collection('attendance')
          .get();
      for (final d in tAttSnap.docs) {
        await d.reference.delete();
      }

      // 3) Delete the teacher document itself
      await _firestore.collection('teachers').doc(email).delete();

      // 4) Try to delete from Firebase Auth if password available
      if (password != null && password.isNotEmpty) {
        try {
          FirebaseApp? secondaryApp;
          try {
            secondaryApp = Firebase.app('secondary');
          } catch (e) {
            secondaryApp = await Firebase.initializeApp(
              name: 'secondary',
              options: DefaultFirebaseOptions.currentPlatform,
            );
          }

          final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
          
          // Sign in to delete account
          await secondaryAuth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          
          // Delete account
          await secondaryAuth.currentUser?.delete();
          await secondaryAuth.signOut();
        } catch (e) {
          print('Could not delete from Firebase Auth: $e');
        }
      }

      return true;
    } catch (e) {
      print('Error deleting teacher: $e');
      rethrow;
    }
  }

  // Delete student (legacy). Prefer deleteStudentCompletely.
  static Future<bool> deleteStudent(String email) async {
    return await deleteStudentCompletely(email);
  }

  // Admin-only: completely remove a student and all of their data
  static Future<bool> deleteStudentCompletely(String email) async {
    try {
      // Guard: only admin can perform
      final current = _auth.currentUser;
      if (current == null || !(current.email?.endsWith('@admin.com') ?? false)) {
        throw Exception('Only admin can delete students');
      }

      final studentRef = _firestore.collection('students').doc(email);
      final studentDoc = await studentRef.get();
      if (!studentDoc.exists) throw Exception('Student not found');
      final studentData = studentDoc.data() as Map<String, dynamic>;

      final storedPassword = (studentData['authPassword'] as String?) ?? (studentData['password'] as String?);

      // 1) Fetch enrolled subjects to clean mirrors
      final enrolledSubjectsSnap = await studentRef.collection('subjects').get();
      final enrolledCodes = <String>[];
      for (final d in enrolledSubjectsSnap.docs) {
        final data = d.data();
        final code = (data['subjectCode'] as String?) ?? d.id;
        if (code.isNotEmpty) enrolledCodes.add(code);
      }

      // 2) Delete all attendance records using student's own subcollection to avoid collection group index
      // We iterate student's attendance, and for each record, delete all mirrored entries
      QuerySnapshot studentAttendanceSnap = await studentRef.collection('attendance').get();
      for (final aDoc in studentAttendanceSnap.docs) {
        final data = aDoc.data() as Map<String, dynamic>;
        final recordId = (data['recordId'] as String?) ?? aDoc.id;
        final subjectCode = (data['subjectCode'] as String?) ?? (data['subject'] as String?);
        final teacherEmail = data['teacherEmail'] as String?;
        final dateStr = data['date'] as String?; // yyyy-MM-dd

        // Delete subject-wise record
        if (subjectCode != null && subjectCode.isNotEmpty) {
          await _firestore
              .collection('attendance')
              .doc(subjectCode)
              .collection('records')
              .doc(recordId)
              .delete()
              .catchError((_) {});
        }

        // Delete teacher-wise record
        if (teacherEmail != null && teacherEmail.isNotEmpty) {
          await _firestore
              .collection('teachers')
              .doc(teacherEmail)
              .collection('attendance')
              .doc(recordId)
              .delete()
              .catchError((_) {});
        }

        // Delete daily attendance record
        if (dateStr != null && dateStr.isNotEmpty) {
          await _firestore
              .collection('daily_attendance')
              .doc(dateStr)
              .collection('records')
              .doc(recordId)
              .delete()
              .catchError((_) {});
        }

        // Delete student's own record
        await aDoc.reference.delete().catchError((_) {});
      }

      // 3) Delete student's attendance_unified fallback
      final unified = await _firestore
          .collection('attendance_unified')
          .where('studentEmail', isEqualTo: email)
          .get();
      for (final doc in unified.docs) {
        await doc.reference.delete();
      }

      // 4) Remove mirrors under subject_enrollments
      for (final code in enrolledCodes) {
        final mirrorRef = _firestore
            .collection('subject_enrollments')
            .doc(code)
            .collection('students')
            .doc(email);
        await mirrorRef.delete().catchError((_) {});
      }

      // 5) Delete subcollections under students/{email}
      final studAttendance = await studentRef.collection('attendance').get();
      for (final doc in studAttendance.docs) {
        await doc.reference.delete();
      }
      final studSubjects = await studentRef.collection('subjects').get();
      for (final doc in studSubjects.docs) {
        await doc.reference.delete();
      }

      // 6) Finally delete the student document and enrollment container
      await studentRef.delete();
      await _firestore.collection('student_enrollments').doc(email).delete().catchError((_) {});

      // 7) Attempt to remove from Firebase Auth if we have a stored password
      if (storedPassword != null && storedPassword.isNotEmpty) {
        try {
          FirebaseApp? secondaryApp;
          try {
            secondaryApp = Firebase.app('admin_worker');
          } catch (_) {
            secondaryApp = await Firebase.initializeApp(
              name: 'admin_worker',
              options: DefaultFirebaseOptions.currentPlatform,
            );
          }
          final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
          await secondaryAuth.signInWithEmailAndPassword(email: email, password: storedPassword);
          await secondaryAuth.currentUser?.delete();
          await secondaryAuth.signOut();
        } catch (e) {
          print('Could not delete Auth user for $email: $e');
        }
      }

      return true;
    } catch (e) {
      print('Error deleting student completely: $e');
      rethrow;
    }
  }

  // Update teacher
  static Future<bool> updateTeacher({
    required String email,
    required String fullName,
    required String subject,
  }) async {
    try {
      final sanitizedName = Validators.sanitizeName(fullName);
      final sanitizedSubject = Validators.sanitizeText(subject);

      await _firestore.collection('teachers').doc(email).update({
        'fullName': sanitizedName,
        'subject': sanitizedSubject,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update subject
      final subjectsQuery = await _firestore
          .collection('subjects')
          .where('teacherEmail', isEqualTo: email)
          .get();

      for (var doc in subjectsQuery.docs) {
        await doc.reference.update({
          'name': sanitizedSubject,
          'code': sanitizedSubject.toUpperCase(),
        });
      }

      return true;
    } catch (e) {
      print('Error updating teacher: $e');
      rethrow;
    }
  }

  // Update student
  static Future<bool> updateStudent({
    required String email,
    required String fullName,
    required List<String> subjects,
  }) async {
    try {
      final sanitizedName = Validators.sanitizeName(fullName);

      await _firestore.collection('students').doc(email).update({
        'fullName': sanitizedName,
        'subjects': subjects,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update enrollment
      await _firestore.collection('student_enrollments').doc(email).update({
        'subjects': subjects,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error updating student: $e');
      rethrow;
    }
  }

  // Get user profile by email
  static Future<Map<String, dynamic>?> getUserProfile(String email) async {
    try {
      // Check if it's a teacher
      final teacherDoc = await _firestore.collection('teachers').doc(email).get();
      if (teacherDoc.exists) {
        final data = teacherDoc.data()!;
        data['role'] = 'teacher';
        return data;
      }

      // Check if it's a student
      final studentDoc = await _firestore.collection('students').doc(email).get();
      if (studentDoc.exists) {
        final data = studentDoc.data()!;
        data['role'] = 'student';
        return data;
      }

      // Check if it's admin
      if (email.endsWith('@admin.com')) {
        return {
          'email': email,
          'fullName': 'Administrator',
          'role': 'admin',
        };
      }

      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Get system statistics
  static Future<Map<String, int>> getSystemStats() async {
    try {
      final teachersSnapshot = await _firestore.collection('teachers').get();
      final studentsSnapshot = await _firestore.collection('students').get();
      final subjectsSnapshot = await _firestore.collection('subjects').get();
      final attendanceSnapshot = await _firestore.collection('attendance_unified').get();

      return {
        'totalTeachers': teachersSnapshot.docs.length,
        'totalStudents': studentsSnapshot.docs.length,
        'totalSubjects': subjectsSnapshot.docs.length,
        'totalAttendance': attendanceSnapshot.docs.length,
      };
    } catch (e) {
      print('Error getting system stats: $e');
      return {
        'totalTeachers': 0,
        'totalStudents': 0,
        'totalSubjects': 0,
        'totalAttendance': 0,
      };
    }
  }
}