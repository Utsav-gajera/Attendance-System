import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'attendance_list_widget.dart';
import 'package:attendance_system/main.dart';
import 'package:attendance_system/firebase_options.dart';
import 'package:intl/intl.dart';
import '../services/attendance_service.dart';
import '../services/enrollment_service.dart';

class TeacherHomeScreen extends StatefulWidget {
  @override
  _TeacherHomeScreenState createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  String? _subjectName;
  String? _subjectCode;
  String? _teacherName;
  bool _showQRCode = false;
  Map<String, String>? _qrData;
  bool _isGeneratingQR = false;
  int _selectedIndex = 0;
  final TextEditingController _studentEmailController = TextEditingController();
  final TextEditingController _studentPasswordController = TextEditingController();
  final TextEditingController _studentNameController = TextEditingController();
  bool _checkingStudent = false;
  bool? _studentExists;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    User? user = FirebaseAuth.instance.currentUser;
    String? teacherEmail = user?.email;
    
    if (teacherEmail != null) {
      try {
        DocumentSnapshot teacherDoc = await _firestore
            .collection('teachers')
            .doc(teacherEmail.toLowerCase())
            .get();
        
        if (teacherDoc.exists) {
          Map<String, dynamic> data = teacherDoc.data() as Map<String, dynamic>;
          // Start with what is available
          String? subjectDisplay = data['subject'];
          String? teacherFullName = data['fullName'] ?? 'Unknown Teacher';

          // Resolve subjectCode and canonical subject name from subjects collection
          try {
            final subjectsSnap = await _firestore
                .collection('subjects')
                .where('teacherEmail', isEqualTo: teacherEmail)
                .limit(1)
                .get();
            if (subjectsSnap.docs.isNotEmpty) {
              final first = subjectsSnap.docs.first;
              final subjData = first.data();
              setState(() {
                _subjectCode = first.id; // canon code for queries and QR
                _subjectName = subjData['name'] ?? subjectDisplay ?? first.id; // display name
                _teacherName = teacherFullName;
              });
            } else {
              setState(() {
                _subjectCode = subjectDisplay; // fallback, likely wrong but better than null
                _subjectName = subjectDisplay ?? 'Unknown Subject';
                _teacherName = teacherFullName;
              });
            }
          } catch (e) {
            print('Error resolving subject code: $e');
            setState(() {
              _subjectCode = subjectDisplay;
              _subjectName = subjectDisplay ?? 'Unknown Subject';
              _teacherName = teacherFullName;
            });
          }
        } else {
          print('Teacher document not found for email: $teacherEmail');
          setState(() {
            _subjectName = 'Unknown Subject';
            _teacherName = 'Unknown Teacher';
          });
        }
      } catch (e) {
        print('Error loading teacher data: $e');
        setState(() {
          _subjectName = 'Error Loading';
          _teacherName = 'Error Loading';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Teacher Dashboard', 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('Subject: ${_subjectName ?? "Loading..."}', 
                style: TextStyle(fontSize: 12, color: Colors.teal[100])),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            child: CircleAvatar(
              backgroundColor: Colors.teal[100],
              child: IconButton(
                icon: Icon(Icons.person, color: Colors.teal[700], size: 20),
                onPressed: () => _showProfileDialog(),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(context),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: Colors.teal[700],
            unselectedItemColor: Colors.grey[600],
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.qr_code_outlined),
                activeIcon: Icon(Icons.qr_code),
                label: 'QR Code',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people_outlined),
                activeIcon: Icon(Icons.people),
                label: 'Students',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.analytics_outlined),
                activeIcon: Icon(Icons.analytics),
                label: 'Analytics',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MyApp()),
      );
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  Widget _buildBody(BuildContext context) {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildQRCodeTab();
      case 2:
        return _buildStudentsTab();
      case 3:
        return _buildAnalyticsTab();
      default:
        return _buildDashboardTab();
    }
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          SizedBox(height: 16),
          _buildQuickStatsGrid(),
          SizedBox(height: 16),
          _buildTodayClassCard(),
          SizedBox(height: 16),
          _buildRecentAttendanceCard(),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal[400]!, Colors.teal[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.school, color: Colors.white, size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${_teacherName ?? "Teacher"}!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'Subject: ${_subjectName ?? "Loading..."}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'Ready to manage your class today?',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Students',
                Icons.people,
                Colors.blue,
                _buildStudentCountWidget(),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Today\'s Present',
                Icons.check_circle,
                Colors.green,
                _buildTodayAttendanceWidget(),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'This Week',
                Icons.calendar_today,
                Colors.orange,
                _buildThisWeekWidget(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, IconData icon, Color color, Widget valueWidget) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: 8),
          valueWidget,
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCountWidget() {
    if (_subjectCode == null) {
      return Text('--', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: EnrollmentService.subjectRosterStream(_subjectCode!),
      builder: (context, snapshot) {
        int count = snapshot.data?.docs.length ?? 0;
        return Text(
          '$count',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        );
      },
    );
  }

  Widget _buildTodayAttendanceWidget() {
    if (_subjectName == null) {
      return Text('--', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
    }
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: AttendanceService.getSubjectAttendance(
        teacherEmail: FirebaseAuth.instance.currentUser?.email,
        subjectCode: _subjectCode,
        date: DateTime.now(),
      ),
      builder: (context, snapshot) {
        int count = snapshot.data?.length ?? 0;
        return Text(
          '$count',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        );
      },
    );
  }

  Widget _buildThisWeekWidget() {
    if (_subjectCode == null) {
      return Text('--', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
    }

    final start = DateTime.now().subtract(Duration(days: 6));
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: AttendanceService.getSubjectAttendance(
        subjectCode: _subjectCode,
        startDate: start,
        endDate: DateTime.now(),
      ),
      builder: (context, snapshot) {
        final records = snapshot.data ?? [];
        final uniqueDays = <String>{};
        for (final r in records) {
          final d = r['date'];
          if (d is String) uniqueDays.add(d);
        }
        return Text(
          '${uniqueDays.length} Days',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        );
      },
    );
  }

  Widget _buildTodayClassCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today, color: Colors.teal[700], size: 24),
              SizedBox(width: 8),
              Text(
                'Today\'s Class',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Spacer(),
              ElevatedButton.icon(
                onPressed: () => setState(() => _selectedIndex = 1),
                icon: Icon(Icons.qr_code, size: 18),
                label: Text('Generate QR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.class_, color: Colors.teal[700], size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _subjectName ?? 'Loading...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal[800],
                        ),
                      ),
                      Text(
                        'Class Session - ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAttendanceCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: Colors.teal[700], size: 24),
              SizedBox(width: 8),
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Spacer(),
              TextButton(
                onPressed: () => setState(() => _selectedIndex = 3),
                child: Text('View All'),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildRecentAttendanceList(),
        ],
      ),
    );
  }

  Widget _buildQRCodeTab() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.teal[200]!),
            ),
            child: Column(
              children: [
                Icon(Icons.qr_code, size: 48, color: Colors.teal[700]),
                SizedBox(height: 16),
                Text(
                  'QR Code Generator',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Generate QR code for students to scan and mark attendance',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.teal[600],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingQR ? null : _generateQRCode,
                  icon: _isGeneratingQR 
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(Icons.qr_code),
                  label: Text(_isGeneratingQR ? 'Generating...' : 'Generate QR Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showQRCode = false;
                      _qrData = null;
                    });
                  },
                  icon: Icon(Icons.clear),
                  label: Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal[700],
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          if (_showQRCode && _qrData != null)
            Expanded(
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Students can scan this QR code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 20),
                    Expanded(
                      child: Center(
                        child: QrImageView(
                          data: _qrData!['qrCode']!,
                          version: QrVersions.auto,
                          size: 250.0,
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.teal[700],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Subject: ${_qrData!['subject']}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.teal[800],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Teacher: ${_qrData!['teacherName']}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.teal[600],
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Valid for 2 hours',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance Analytics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          _buildAttendanceChart(),
          SizedBox(height: 16),
          _buildStudentPerformance(),
        ],
      ),
    );
  }

  Widget _buildAttendanceChart() {
    final start = DateTime.now().subtract(Duration(days: 6));
    final end = DateTime.now();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Attendance Trend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
      future: AttendanceService.getSubjectAttendance(
              subjectCode: _subjectCode,
              startDate: start,
              endDate: end,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(height: 120, child: Center(child: CircularProgressIndicator()));
              }

              final records = snapshot.data ?? [];
              if (records.isEmpty) {
                return Container(
                  height: 120,
                  child: Center(
                    child: Text('No attendance in the last 7 days', style: TextStyle(color: Colors.grey[600])),
                  ),
                );
              }

              // Count per day
              final counts = <String, int>{};
              for (int i = 0; i < 7; i++) {
                final d = DateTime(start.year, start.month, start.day + i);
                final key = DateFormat('MMM d').format(d);
                counts[key] = 0;
              }
              for (final r in records) {
                final dateStr = r['date'] as String?;
                if (dateStr != null) {
                  final d = DateTime.parse(dateStr);
                  final key = DateFormat('MMM d').format(d);
                  if (counts.containsKey(key)) counts[key] = (counts[key] ?? 0) + 1;
                }
              }

              return Column(
                children: counts.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        SizedBox(width: 80, child: Text(e.key, style: TextStyle(color: Colors.grey[700]))),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: (e.value) / (records.length == 0 ? 1 : records.length),
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation(Colors.teal[400]!),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('${e.value}', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStudentPerformance() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Student Performance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          _buildStudentPerformanceList(),
        ],
      ),
    );
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person, color: Colors.teal[700]),
              SizedBox(width: 8),
              Text('Teacher Profile'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: ${_teacherName ?? "Not available"}'),
              SizedBox(height: 8),
              Text('Subject: ${_subjectName ?? "Not assigned"}'),
              SizedBox(height: 8),
              Text('Email: ${FirebaseAuth.instance.currentUser?.email ?? "Not available"}'),
              SizedBox(height: 8),
              Text('Role: Teacher'),
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _signOut(context);
                  },
                  icon: Icon(Icons.logout),
                  label: Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentAttendanceList() {
    if (_subjectName == null) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Text(
          'No subject assigned',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: AttendanceService.getSubjectAttendance(
        teacherEmail: FirebaseAuth.instance.currentUser?.email,
        subjectCode: _subjectCode,
        startDate: DateTime.now().subtract(Duration(days: 7)),
        endDate: DateTime.now(),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: EdgeInsets.all(16),
            child: Text(
              'No attendance records yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }
        
        return Column(
          children: snapshot.data!.take(3).map((data) {
            return Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['studentName'] ?? 'Unknown Student',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[800],
                          ),
                        ),
                        Text(
                          '${data['date']} at ${data['time']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Present',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildStudentPerformanceList() {
    if (_subjectName == null) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Text(
          'No subject assigned',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _subjectCode == null
          ? const Stream.empty()
          : EnrollmentService.subjectRosterStream(_subjectCode!),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: EdgeInsets.all(16),
            child: Text(
              'No students enrolled',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        return Column(
          children: snapshot.data!.docs.take(5).map((doc) {
            final data = doc.data();
            final studentName = data['studentName'] ?? 'Unknown Student';
            final email = data['studentEmail'] ?? 'no-email';

            return Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: Icon(Icons.person, color: Colors.blue[600], size: 16),
                    radius: 16,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                          ),
                        ),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '—', // Placeholder for attendance rate
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildHomeTab() {
    return Container(
      padding: EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.school,
            size: 80.0,
            color: Colors.blue,
          ),
          SizedBox(height: 10.0),
          Text(
            'Welcome, Teacher!',
            style: TextStyle(
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_subjectName != null) ...[
            SizedBox(height: 5.0),
            Text(
              'Subject: $_subjectName',
              style: TextStyle(
                fontSize: 16.0,
                color: Colors.grey[600],
              ),
            ),
          ],
          SizedBox(height: 20.0),
          if (_showQRCode && _subjectName != null) ...[
            _buildQRCodeSection(),
            SizedBox(height: 20.0),
          ],
          Expanded(
            child: _buildAttendanceList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAddStudentSection(),
          SizedBox(height: 20),
          _buildStudentsList(),
        ],
      ),
    );
  }

  Widget _buildCalendarTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          TableCalendar<String>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            eventLoader: _getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
            ),
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              }
            },
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
          SizedBox(height: 20),
          if (_selectedDay != null) _buildSelectedDayEvents(),
        ],
      ),
    );
  }

  Widget _buildQRCodeSection() {
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'QR Code for Attendance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Students should scan this QR code to mark attendance',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 15),
          QrImageView(
            data: _subjectCode ?? _subjectName ?? '',
            version: QrVersions.auto,
            size: 200.0,
            backgroundColor: Colors.white,
          ),
          SizedBox(height: 10),
          Text(
            'Subject: $_subjectName',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList(BuildContext context) {
    if (_subjectCode == null) {
      return Center(
        child: Text('Subject not found.'),
      );
    }

    return AttendanceListWidget(subjectCode: _subjectCode!);
  }

  Widget _buildAddStudentSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add / Assign Student',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _studentEmailController,
              decoration: InputDecoration(
                labelText: 'Student Email',
                hintText: 'student@student.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _checkingStudent ? null : _checkStudent,
                    icon: _checkingStudent
                        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(Icons.search),
                    label: Text(_checkingStudent ? 'Checking...' : 'Check'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                if (_studentExists == true)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _assignStudentToCurrentSubject,
                      icon: Icon(Icons.assignment_turned_in),
                      label: Text('Assign Subject'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    ),
                  ),
              ],
            ),
            if (_studentExists == false) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange[200]!)),
                child: Row(children: [
                  Icon(Icons.info, color: Colors.orange[700]),
                  SizedBox(width: 8),
                  Expanded(child: Text('Student not found. Add student, then assign to this subject.')),
                ]),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _studentNameController,
                decoration: InputDecoration(
                  labelText: 'Student Full Name',
                  hintText: 'e.g., John Smith, Maria Garcia',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _studentPasswordController,
                decoration: InputDecoration(
                  labelText: 'Password (for new account)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addStudent,
                  icon: Icon(Icons.person_add),
                  label: Text('Create Student'),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsList() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Students List',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _subjectCode == null
                  ? const Stream.empty()
                  : EnrollmentService.subjectRosterStream(_subjectCode!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Text('No students found');
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data();
                    final fullName = data['studentName'] ?? 'Unknown Student';
                    final email = data['studentEmail'] ?? 'no-email';

                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal[100],
                          child: Text(
                            (fullName.isNotEmpty ? fullName[0] : '?').toUpperCase(),
                            style: TextStyle(
                              color: Colors.teal[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          fullName,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Email: $email',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => _removeStudentFromCurrentSubject(email),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDayEvents() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance for ${_formatDate(_selectedDay!)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('attendance')
                  .doc(_subjectCode)
                  .collection('records')
                  .where('date', isEqualTo: _formatDate(_selectedDay!))
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Text('No attendance recorded for this day');
                }
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var attendance = snapshot.data!.docs[index];
                    var data = attendance.data() as Map<String, dynamic>;
                    
                    return ListTile(
                      leading: Icon(Icons.check_circle, color: Colors.green),
                      title: Text(data['studentName'] ?? 'Unknown'),
                      subtitle: Text('Time: ${data['time'] ?? 'Unknown'}'),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getEventsForDay(DateTime day) {
    // This would typically fetch events from Firestore
    // For now, return empty list
    return [];
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _checkStudent() async {
    final email = _studentEmailController.text.trim().toLowerCase();
    if (!email.endsWith('@student.com')) {
      _showError('Student email must end with @student.com');
      return;
    }
    setState(() => _checkingStudent = true);
    try {
      final doc = await _firestore.collection('students').doc(email).get();
      setState(() {
        _studentExists = doc.exists;
      });
      if (doc.exists) {
        _showSuccess('Student exists. You can assign the subject.');
      } else {
        _showWarning('Student does not exist. Please create the student.');
      }
    } catch (e) {
      _showError('Check failed: ${e.toString()}');
    } finally {
      setState(() => _checkingStudent = false);
    }
  }

  Future<void> _assignStudentToCurrentSubject() async {
    final email = _studentEmailController.text.trim().toLowerCase();
    if (_subjectCode == null || _subjectName == null) {
      _showError('Subject not loaded yet');
      return;
    }
    final teacherEmail = FirebaseAuth.instance.currentUser?.email;
    if (teacherEmail == null) {
      _showError('Teacher not authenticated');
      return;
    }
    try {
      final studentDoc = await _firestore.collection('students').doc(email).get();
      if (!studentDoc.exists) {
        _showError('Student not found. Create student first.');
        return;
      }
      // Check if already assigned to this subject
      final currentAssign = await _firestore
          .collection('students')
          .doc(email)
          .collection('subjects')
          .doc(_subjectCode!)
          .get();
      if (currentAssign.exists) {
        _showInfo('This student is already assigned to $_subjectName');
        return;
      }

      final data = studentDoc.data() as Map<String, dynamic>;
      final name = data['fullName'] ?? data['name'] ?? email.split('@')[0];
      await EnrollmentService.enrollStudentToSubject(
        studentEmail: email,
        studentName: name,
        subjectCode: _subjectCode!,
        subjectName: _subjectName!,
        teacherEmail: teacherEmail,
        teacherName: _teacherName ?? 'Teacher',
      );
      _showSuccess('Assigned $email to $_subjectName');
      setState(() {
        _studentExists = true;
      });
    } catch (e) {
      _showError('Failed to assign subject: ${e.toString()}');
    }
  }

  Future<void> _addStudent() async {
    // Basic validations: name and email required; password optional for existing students
    if (_studentNameController.text.isEmpty || _studentEmailController.text.isEmpty) {
      _showError('Please fill name and email');
      return;
    }

    if (!_studentEmailController.text.endsWith('@student.com')) {
      _showError('Student email must end with @student.com');
      return;
    }

    final String studentEmail = _studentEmailController.text.trim().toLowerCase();
    final String studentPassword = _studentPasswordController.text.trim();

    if (studentPassword.isNotEmpty && studentPassword.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    try {
      if (_subjectCode == null || _subjectName == null) {
        _showError('Subject not loaded yet');
        return;
      }

      // Ensure teacher identity
      final teacherEmail = FirebaseAuth.instance.currentUser?.email;
      if (teacherEmail == null) {
        _showError('Teacher not authenticated');
        return;
      }

      // Determine if student document already exists
      final studentDoc = await _firestore.collection('students').doc(studentEmail).get();
      final bool studentExists = studentDoc.exists;

      bool createdAuthUser = false;

      // Create auth user only when password provided and account likely not present
      if (studentPassword.isNotEmpty && !studentExists) {
        FirebaseApp secondaryApp;
        try {
          secondaryApp = Firebase.app('teacher_worker');
        } catch (_) {
          secondaryApp = await Firebase.initializeApp(
            name: 'teacher_worker',
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
        final FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
        try {
          await secondaryAuth.createUserWithEmailAndPassword(
            email: studentEmail,
            password: studentPassword,
          );
          createdAuthUser = true;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            // OK: proceed with enrollment
            createdAuthUser = false;
          } else {
            rethrow;
          }
        }
      } else if (!studentExists && studentPassword.isEmpty) {
        // No account and no password - ask teacher to provide password
        _showError('Student account not found. Provide a password to create a new account.');
        return;
      }

      // Create or update the base student document only (do not auto-assign subject)
      await _firestore.collection('students').doc(studentEmail).set({
        'fullName': _studentNameController.text,
        'name': _studentNameController.text, // backward compatibility
        'email': studentEmail,
        'createdAt': FieldValue.serverTimestamp(),
        if (createdAuthUser) 'authPassword': studentPassword, // legacy field
      }, SetOptions(merge: true));

      _showSuccess('Student created. Now click "Assign Subject" to add them to $_subjectName');
      setState(() {
        _studentExists = true;
      });

      // Keep email; clear only name/password so teacher can assign right away
      _studentNameController.clear();
      _studentPasswordController.clear();

    } catch (e) {
      print('Error adding/enrolling student: $e');
      _showError('Failed to enroll student: ${e.toString()}');
    }
  }

  Future<void> _deleteStudent(String studentId, String? studentEmail) async {
    // Confirm deletion with dialog
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Student'),
          content: Text('Are you sure you want to permanently delete this student? This will remove their account and all data.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      // First get the student data to retrieve the stored password
      DocumentSnapshot studentDoc = await _firestore.collection('students').doc(studentId).get();
      Map<String, dynamic>? studentData = studentDoc.data() as Map<String, dynamic>?;
      String? storedPassword = studentData?['authPassword'];
      
      // Delete from Firestore first
      await _firestore.collection('students').doc(studentId).delete();
      
      // Try to delete from Firebase Auth using stored password
      if (studentEmail != null && studentEmail.isNotEmpty && storedPassword != null && storedPassword.isNotEmpty) {
        try {
          // Use a secondary Firebase app to delete the user
          FirebaseApp secondaryApp;
          try {
            secondaryApp = Firebase.app('teacher_worker');
          } catch (_) {
            secondaryApp = await Firebase.initializeApp(
              name: 'teacher_worker',
              options: DefaultFirebaseOptions.currentPlatform,
            );
          }

          final FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
          
          // Sign in with the student's credentials to get the user object
          try {
            UserCredential userCredential = await secondaryAuth.signInWithEmailAndPassword(
              email: studentEmail,
              password: storedPassword,
            );
            
            // Delete the user
            await userCredential.user?.delete();
            
            // Sign out from secondary app
            await secondaryAuth.signOut();
            
            print('Student successfully removed from Firebase Auth');
            _showSuccess('Student completely removed from system!');
            
          } catch (authError) {
            print('Could not delete from Firebase Auth: $authError');
            _showSuccess('Student removed from database. Note: Auth account may still exist.');
          }
          
        } catch (e) {
          print('Error during Auth deletion process: $e');
          _showSuccess('Student removed from database. Note: Auth account may still exist.');
        }
      } else {
        print('No stored password found for auth deletion');
        _showSuccess('Student removed from database. Note: Auth account may still exist.');
      }
      
    } catch (e) {
      print('Error deleting student: $e');
      _showError('Failed to delete student');
    }
  }

  Future<void> _removeStudentFromCurrentSubject(String studentEmail) async {
    if (_subjectCode == null) {
      _showError('Subject not loaded');
      return;
    }

    // Confirm removal
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove from Subject'),
        content: Text('Remove this student from $_subjectName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Remove')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await EnrollmentService.removeStudentFromSubject(
        studentEmail: studentEmail,
        subjectCode: _subjectCode!,
      );
      _showSuccess('Student removed from $_subjectName');
    } catch (e) {
      _showError('Failed to remove: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  Future<void> _generateQRCode() async {
    if (_subjectCode == null) {
      _showError('Subject not loaded yet');
      return;
    }
    
    final teacherEmail = FirebaseAuth.instance.currentUser?.email;
    if (teacherEmail == null) {
      _showError('Teacher not authenticated');
      return;
    }
    
    setState(() {
      _isGeneratingQR = true;
    });
    
    try {
      final qrData = await AttendanceService.generateQRCodeData(
        teacherEmail: teacherEmail,
        subjectCode: _subjectCode!,
      );
      
      setState(() {
        _qrData = qrData;
        _showQRCode = true;
        _isGeneratingQR = false;
      });
      
      _showSuccess('QR code generated successfully! Valid for 2 hours.');
      
    } catch (e) {
      setState(() {
        _isGeneratingQR = false;
      });
      _showError('Failed to generate QR code: ${e.toString()}');
    }
  }
}
