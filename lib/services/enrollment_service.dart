import 'package:cloud_firestore/cloud_firestore.dart';

class EnrollmentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Enroll a student into a subject (idempotent)
  // Ensures many-to-many relation using two mirrored collections:
  // - students/{studentEmail}/subjects/{subjectCode}
  // - subject_enrollments/{subjectCode}/students/{studentEmail}
  static Future<void> enrollStudentToSubject({
    required String studentEmail,
    required String studentName,
    required String subjectCode,
    required String subjectName,
    required String teacherEmail,
    required String teacherName,
  }) async {
    final email = studentEmail.trim().toLowerCase();
    final code = subjectCode.trim();
    final now = DateTime.now();

    final batch = _firestore.batch();

    // 1) Upsert student base doc (no single-subject field)
    final studentRef = _firestore.collection('students').doc(email);
    batch.set(studentRef, {
      'email': email,
      'fullName': studentName,
      'updatedAt': FieldValue.serverTimestamp(),
      'subjects': FieldValue.arrayUnion([code]),
    }, SetOptions(merge: true));

    // 2) Student -> Subjects subcollection
    final studentSubjectRef = studentRef.collection('subjects').doc(code);
    batch.set(studentSubjectRef, {
      'subjectCode': code,
      'subjectName': subjectName,
      'teacherEmail': teacherEmail,
      'teacherName': teacherName,
      'enrolledAt': FieldValue.serverTimestamp(),
      'totalAttendance': 0,
      'lastAttendance': null,
    }, SetOptions(merge: true));

    // 3) Subject -> Students mirror for easy roster queries
    final subjectStudentRef = _firestore
        .collection('subject_enrollments')
        .doc(code)
        .collection('students')
        .doc(email);
    batch.set(subjectStudentRef, {
      'studentEmail': email,
      'studentName': studentName,
      'teacherEmail': teacherEmail,
      'teacherName': teacherName,
      'subjectCode': code,
      'subjectName': subjectName,
      'enrolledAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // Remove a student from a subject (does not delete the student's account)
  static Future<void> removeStudentFromSubject({
    required String studentEmail,
    required String subjectCode,
  }) async {
    final email = studentEmail.trim().toLowerCase();
    final code = subjectCode.trim();

    final batch = _firestore.batch();

    // Remove mirror doc under subject_enrollments
    final subjectStudentRef = _firestore
        .collection('subject_enrollments')
        .doc(code)
        .collection('students')
        .doc(email);
    batch.delete(subjectStudentRef);

    // Remove student->subject subdoc
    final studentSubjectRef = _firestore
        .collection('students')
        .doc(email)
        .collection('subjects')
        .doc(code);
    batch.delete(studentSubjectRef);

    // Update student's subjects array
    final studentRef = _firestore.collection('students').doc(email);
    batch.set(studentRef, {
      'subjects': FieldValue.arrayRemove([code]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // Stream roster for a subject
  static Stream<QuerySnapshot<Map<String, dynamic>>> subjectRosterStream(String subjectCode) {
    final code = subjectCode.trim();
    return _firestore
        .collection('subject_enrollments')
        .doc(code)
        .collection('students')
        .orderBy('studentName')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? {},
          toFirestore: (data, _) => data,
        )
        .snapshots();
  }
}