import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get attendance statistics for a specific period
  static Future<AttendanceStats> getAttendanceStats({
    String? teacherEmail,
    String? studentEmail,
    String? subject,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      startDate ??= DateTime.now().subtract(Duration(days: 30));
      endDate ??= DateTime.now();

      Query query = _firestore.collection('attendance_unified');

      // Apply filters
      if (teacherEmail != null) query = query.where('teacherEmail', isEqualTo: teacherEmail);
      if (studentEmail != null) query = query.where('studentEmail', isEqualTo: studentEmail);
      if (subject != null) query = query.where('subject', isEqualTo: subject);
      
      query = query.where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startDate));
      query = query.where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endDate));

      final snapshot = await query.get();
      
      return AttendanceStats.fromQuerySnapshot(snapshot, startDate, endDate);
    } catch (e) {
      print('Error getting attendance stats: $e');
      return AttendanceStats.empty();
    }
  }

  // Get weekly attendance data for charts
  static Future<List<WeeklyData>> getWeeklyAttendance({
    String? teacherEmail,
    String? studentEmail,
    String? subject,
    int weeks = 4,
  }) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: weeks * 7));
      
      Query query = _firestore.collection('attendance_unified');
      
      if (teacherEmail != null) query = query.where('teacherEmail', isEqualTo: teacherEmail);
      if (studentEmail != null) query = query.where('studentEmail', isEqualTo: studentEmail);
      if (subject != null) query = query.where('subject', isEqualTo: subject);
      
      query = query.where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startDate));
      query = query.where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endDate));

      final snapshot = await query.get();
      
      // Group by weeks
      final weeklyMap = <String, int>{};
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dateStr = data['date'] as String;
        final date = DateTime.parse(dateStr);
        
        // Calculate week start (Monday)
        final weekStart = date.subtract(Duration(days: date.weekday - 1));
        final weekKey = DateFormat('MMM dd').format(weekStart);
        
        weeklyMap[weekKey] = (weeklyMap[weekKey] ?? 0) + 1;
      }
      
      return weeklyMap.entries
          .map((e) => WeeklyData(week: e.key, count: e.value))
          .toList()
        ..sort((a, b) => a.week.compareTo(b.week));
        
    } catch (e) {
      print('Error getting weekly attendance: $e');
      return [];
    }
  }

  // Get attendance by subject
  static Future<List<SubjectData>> getAttendanceBySubject({
    String? studentEmail,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      startDate ??= DateTime.now().subtract(Duration(days: 30));
      endDate ??= DateTime.now();

      Query query = _firestore.collection('attendance_unified');
      
      if (studentEmail != null) query = query.where('studentEmail', isEqualTo: studentEmail);
      query = query.where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startDate));
      query = query.where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endDate));

      final snapshot = await query.get();
      
      final subjectMap = <String, int>{};
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final subject = data['subject'] as String? ?? 'Unknown';
        subjectMap[subject] = (subjectMap[subject] ?? 0) + 1;
      }
      
      return subjectMap.entries
          .map((e) => SubjectData(subject: e.key, count: e.value))
          .toList()
        ..sort((a, b) => b.count.compareTo(a.count));
        
    } catch (e) {
      print('Error getting attendance by subject: $e');
      return [];
    }
  }

  // Get attendance trends for a student
  static Future<List<TrendData>> getAttendanceTrends({
    required String studentEmail,
    int days = 30,
  }) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));
      
      final query = _firestore.collection('attendance_unified')
          .where('studentEmail', isEqualTo: studentEmail)
          .where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startDate))
          .where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endDate))
          .orderBy('date');

      final snapshot = await query.get();
      
      final dailyMap = <String, int>{};
      
      // Initialize all days with 0
      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));
        dailyMap[DateFormat('MM-dd').format(date)] = 0;
      }
      
      // Count attendance per day
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dateStr = data['date'] as String;
        final date = DateTime.parse(dateStr);
        final dayKey = DateFormat('MM-dd').format(date);
        
        if (dailyMap.containsKey(dayKey)) {
          dailyMap[dayKey] = (dailyMap[dayKey] ?? 0) + 1;
        }
      }
      
      return dailyMap.entries
          .map((e) => TrendData(date: e.key, count: e.value))
          .toList();
        
    } catch (e) {
      print('Error getting attendance trends: $e');
      return [];
    }
  }

  // Export attendance data to CSV format
  static Future<String> exportToCSV({
    String? teacherEmail,
    String? studentEmail,
    String? subject,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      startDate ??= DateTime.now().subtract(Duration(days: 30));
      endDate ??= DateTime.now();

      Query query = _firestore.collection('attendance_unified');

      if (teacherEmail != null) query = query.where('teacherEmail', isEqualTo: teacherEmail);
      if (studentEmail != null) query = query.where('studentEmail', isEqualTo: studentEmail);
      if (subject != null) query = query.where('subject', isEqualTo: subject);
      
      query = query.where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startDate));
      query = query.where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endDate));
      query = query.orderBy('date', descending: true);

      final snapshot = await query.get();
      
      StringBuffer csv = StringBuffer();
      csv.writeln('Date,Time,Student Name,Student Email,Subject,Teacher Name');
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        csv.writeln([
          data['date'] ?? '',
          data['time'] ?? '',
          data['studentName'] ?? '',
          data['studentEmail'] ?? '',
          data['subject'] ?? '',
          data['teacherName'] ?? '',
        ].join(','));
      }
      
      return csv.toString();
    } catch (e) {
      print('Error exporting to CSV: $e');
      return '';
    }
  }

  // Get top performing students
  static Future<List<StudentPerformance>> getTopStudents({
    String? subject,
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      startDate ??= DateTime.now().subtract(Duration(days: 30));
      endDate ??= DateTime.now();

      Query query = _firestore.collection('attendance_unified');
      
      if (subject != null) query = query.where('subject', isEqualTo: subject);
      query = query.where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startDate));
      query = query.where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endDate));

      final snapshot = await query.get();
      
      final studentMap = <String, StudentPerformance>{};
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final studentEmail = data['studentEmail'] as String? ?? '';
        final studentName = data['studentName'] as String? ?? '';
        
        if (studentEmail.isNotEmpty) {
          if (studentMap.containsKey(studentEmail)) {
            studentMap[studentEmail]!.attendanceCount++;
          } else {
            studentMap[studentEmail] = StudentPerformance(
              studentName: studentName,
              studentEmail: studentEmail,
              attendanceCount: 1,
            );
          }
        }
      }
      
      final sortedStudents = studentMap.values.toList()
        ..sort((a, b) => b.attendanceCount.compareTo(a.attendanceCount));
      
      return sortedStudents.take(limit).toList();
    } catch (e) {
      print('Error getting top students: $e');
      return [];
    }
  }
}

// Data models for analytics
class AttendanceStats {
  final int totalAttendance;
  final int uniqueStudents;
  final int uniqueDays;
  final double averageDaily;
  final Map<String, int> dailyBreakdown;
  final DateTime startDate;
  final DateTime endDate;

  AttendanceStats({
    required this.totalAttendance,
    required this.uniqueStudents,
    required this.uniqueDays,
    required this.averageDaily,
    required this.dailyBreakdown,
    required this.startDate,
    required this.endDate,
  });

  factory AttendanceStats.fromQuerySnapshot(QuerySnapshot snapshot, DateTime start, DateTime end) {
    final docs = snapshot.docs;
    final uniqueStudentsSet = <String>{};
    final uniqueDaysSet = <String>{};
    final dailyBreakdown = <String, int>{};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final studentEmail = data['studentEmail'] as String? ?? '';
      final date = data['date'] as String? ?? '';

      if (studentEmail.isNotEmpty) uniqueStudentsSet.add(studentEmail);
      if (date.isNotEmpty) {
        uniqueDaysSet.add(date);
        dailyBreakdown[date] = (dailyBreakdown[date] ?? 0) + 1;
      }
    }

    final totalDays = end.difference(start).inDays + 1;
    final avgDaily = uniqueDaysSet.isNotEmpty ? docs.length / uniqueDaysSet.length : 0.0;

    return AttendanceStats(
      totalAttendance: docs.length,
      uniqueStudents: uniqueStudentsSet.length,
      uniqueDays: uniqueDaysSet.length,
      averageDaily: avgDaily,
      dailyBreakdown: dailyBreakdown,
      startDate: start,
      endDate: end,
    );
  }

  factory AttendanceStats.empty() {
    return AttendanceStats(
      totalAttendance: 0,
      uniqueStudents: 0,
      uniqueDays: 0,
      averageDaily: 0.0,
      dailyBreakdown: {},
      startDate: DateTime.now(),
      endDate: DateTime.now(),
    );
  }
}

class WeeklyData {
  final String week;
  final int count;

  WeeklyData({required this.week, required this.count});
}

class SubjectData {
  final String subject;
  final int count;

  SubjectData({required this.subject, required this.count});
}

class TrendData {
  final String date;
  final int count;

  TrendData({required this.date, required this.count});
}

class StudentPerformance {
  final String studentName;
  final String studentEmail;
  int attendanceCount;

  StudentPerformance({
    required this.studentName,
    required this.studentEmail,
    required this.attendanceCount,
  });
}