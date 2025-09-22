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

    // Keep legacy student_enrollments in sync for other parts of the app
    await _firestore.collection('student_enrollments').doc(email).set({
      'studentEmail': email,
      'subjects': FieldValue.arrayUnion([code]),
      'enrolledAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

    // Also update legacy student_enrollments view
    await _firestore.collection('student_enrollments').doc(email).set({
      'studentEmail': email,
      'subjects': FieldValue.arrayRemove([code]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Cascade delete attendance for this student and subject
    // Query student's own attendance subcollection for this subject (no composite index required)
    final attendanceSnap = await studentRef
        .collection('attendance')
        .where('subjectCode', isEqualTo: code)
        .get();

    for (final doc in attendanceSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final recordId = (data['recordId'] as String?) ?? doc.id;
      final teacherEmail = data['teacherEmail'] as String?;
      final dateStr = data['date'] as String?; // yyyy-MM-dd

      // Delete subject-wise attendance
      await _firestore
          .collection('attendance')
          .doc(code)
          .collection('records')
          .doc(recordId)
          .delete()
          .catchError((_) {});

      // Delete teacher-wise attendance mirror
      if (teacherEmail != null && teacherEmail.isNotEmpty) {
        await _firestore
            .collection('teachers')
            .doc(teacherEmail)
            .collection('attendance')
            .doc(recordId)
            .delete()
            .catchError((_) {});
      }

      // Delete daily attendance mirror
      if (dateStr != null && dateStr.isNotEmpty) {
        await _firestore
            .collection('daily_attendance')
            .doc(dateStr)
            .collection('records')
            .doc(recordId)
            .delete()
            .catchError((_) {});
      }

      // Finally delete the student's own record
      await doc.reference.delete().catchError((_) {});
    }
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