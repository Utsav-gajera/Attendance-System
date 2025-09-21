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
      final password = teacherData['password'] as String?;

      // Delete from Firestore
      await _firestore.collection('teachers').doc(email).delete();

      // Delete associated subjects
      final subjectsQuery = await _firestore
          .collection('subjects')
          .where('teacherEmail', isEqualTo: email)
          .get();

      for (var doc in subjectsQuery.docs) {
        await doc.reference.delete();
      }

      // Try to delete from Firebase Auth if password available
      if (password != null) {
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

  // Delete student
  static Future<bool> deleteStudent(String email) async {
    try {
      // Get student data first
      final studentDoc = await _firestore.collection('students').doc(email).get();
      if (!studentDoc.exists) {
        throw Exception('Student not found');
      }

      final studentData = studentDoc.data() as Map<String, dynamic>;
      final password = studentData['password'] as String?;

      // Delete from Firestore
      await _firestore.collection('students').doc(email).delete();
      
      // Delete enrollment
      await _firestore.collection('student_enrollments').doc(email).delete();

      // Delete attendance records
      final attendanceQuery = await _firestore
          .collection('attendance_unified')
          .where('studentEmail', isEqualTo: email)
          .get();

      for (var doc in attendanceQuery.docs) {
        await doc.reference.delete();
      }

      // Try to delete from Firebase Auth if password available
      if (password != null) {
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
      print('Error deleting student: $e');
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