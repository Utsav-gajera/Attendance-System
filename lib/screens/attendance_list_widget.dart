import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceListWidget extends StatelessWidget {
  final String subjectCode;

  AttendanceListWidget({required this.subjectCode});

  @override
  Widget build(BuildContext context) {
    DateTime currentDate = DateTime.now();
    final String today = _formatDate(currentDate);

    // Stream today's attendance records from the new structure:
    // attendance/{subjectCode}/records where date == today
    final Stream<QuerySnapshot> attendanceStream = FirebaseFirestore.instance
        .collection('attendance')
        .doc(subjectCode)
        .collection('records')
        .where('date', isEqualTo: today)
        .orderBy('timestamp', descending: false)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: attendanceStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No attendance recorded for $subjectCode on $today',
              style: TextStyle(fontSize: 16.0, color: Colors.grey),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(4.0),
              child: Text(
                'Attended Students for $subjectCode',
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(4.0),
              child: Text(
                'Date: $today',
                style: TextStyle(
                  fontSize: 14.0,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final studentName = data['studentName'] ?? data['studentEmail'] ?? 'Unknown Student';
                  final time = data['time'] ?? '';
                  return Container(
                    margin: EdgeInsets.only(bottom: 4.0),
                    child: ListTile(
                      dense: true,
                      visualDensity: VisualDensity(horizontal: 0, vertical: -4),
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 0.0,
                        horizontal: 8.0,
                      ),
                      title: Text(
                        '${index + 1}. $studentName',
                        style: TextStyle(fontSize: 16.0),
                      ),
                      subtitle: time.isNotEmpty ? Text('Time: $time') : null,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Helper method to format the date as 'YYYY-MM-DD'
  String _formatDate(DateTime date) {
    return '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';
  }

  // Helper method to add a leading zero if the number is a single digit
  String _twoDigits(int n) {
    if (n >= 10) return '$n';
    return '0$n';
  }
}
