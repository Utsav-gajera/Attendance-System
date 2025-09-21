import 'package:flutter/material.dart';
import 'package:attendance_system/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'attendance_confirmation_screen.dart';
import 'package:intl/intl.dart';

class StudentHomeScreen extends StatefulWidget {
  final String username;

  StudentHomeScreen(this.username);

  @override
  _StudentHomeScreenState createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _selectedIndex = 0;
  DateTime _selectedDate = DateTime.now();

  // Method to sign out the user
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.indigo[600],
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello, ${widget.username}', 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            Text('Student Portal', 
                style: TextStyle(fontSize: 12, color: Colors.indigo[100])),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            child: CircleAvatar(
              backgroundColor: Colors.indigo[100],
              child: IconButton(
                icon: Icon(Icons.person, color: Colors.indigo[600], size: 20),
                onPressed: () => _showProfileDialog(),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
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
            selectedItemColor: Colors.indigo[600],
            unselectedItemColor: Colors.grey[600],
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.qr_code_scanner_outlined),
                activeIcon: Icon(Icons.qr_code_scanner),
                label: 'Scan QR',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.analytics_outlined),
                activeIcon: Icon(Icons.analytics),
                label: 'Attendance',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.schedule_outlined),
                activeIcon: Icon(Icons.schedule),
                label: 'Schedule',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildQRScannerTab();
      case 2:
        return _buildAttendanceTab();
      case 3:
        return _buildScheduleTab();
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
          _buildQuickActionsGrid(),
          SizedBox(height: 16),
          _buildTodayAttendanceCard(),
          SizedBox(height: 16),
          _buildRecentActivityCard(),
          SizedBox(height: 16),
          _buildUpcomingClassesCard(),
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
          colors: [Colors.indigo[400]!, Colors.indigo[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
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
                      'Good ${_getTimeOfDayGreeting()}!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMM d').format(DateTime.now()),
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
            'Ready to mark your attendance today?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
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
                child: _buildActionCard(
                  'Scan QR',
                  Icons.qr_code_scanner,
                  Colors.green,
                  () => setState(() => _selectedIndex = 1),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  'View Attendance',
                  Icons.bar_chart,
                  Colors.blue,
                  () => setState(() => _selectedIndex = 2),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  'Class Schedule',
                  Icons.schedule,
                  Colors.orange,
                  () => setState(() => _selectedIndex = 3),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  'Profile',
                  Icons.person,
                  Colors.purple,
                  () => _showProfileDialog(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayAttendanceCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('students')
          .where('email', isEqualTo: '${widget.username}@student.com')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container();
        }
        
        var studentData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        String subject = studentData['subject'] ?? 'Unknown';
        
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
                  Icon(Icons.today, color: Colors.indigo[600], size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Today\'s Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _buildTodayAttendanceStatus(subject),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTodayAttendanceStatus(String subject) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .doc(subject)
          .collection('daily')
          .where('studentName', isEqualTo: widget.username)
          .where('date', isEqualTo: DateFormat('yyyy-MM-dd').format(DateTime.now()))
          .snapshots(),
      builder: (context, snapshot) {
        bool isPresent = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isPresent ? Colors.green[50] : Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPresent ? Colors.green[200]! : Colors.orange[200]!,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isPresent ? Icons.check_circle : Icons.pending,
                color: isPresent ? Colors.green[600] : Colors.orange[600],
                size: 24,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPresent ? 'Present' : 'Not Marked Yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isPresent ? Colors.green[800] : Colors.orange[800],
                      ),
                    ),
                    Text(
                      subject,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isPresent)
                ElevatedButton(
                  onPressed: () => setState(() => _selectedIndex = 1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text('Mark Now'),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentActivityCard() {
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
              Icon(Icons.history, color: Colors.indigo[600], size: 24),
              SizedBox(width: 8),
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildRecentAttendanceList(),
        ],
      ),
    );
  }

  Widget _buildUpcomingClassesCard() {
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
              Icon(Icons.upcoming, color: Colors.indigo[600], size: 24),
              SizedBox(width: 8),
              Text(
                'Upcoming Classes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildUpcomingClassesList(),
        ],
      ),
    );
  }

  String _getTimeOfDayGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person, color: Colors.indigo[600]),
              SizedBox(width: 8),
              Text('Profile'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Username: ${widget.username}'),
              SizedBox(height: 8),
              Text('Email: ${widget.username}@student.com'),
              SizedBox(height: 8),
              Text('Role: Student'),
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

  Widget _buildQRScannerTab() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              children: [
                Icon(Icons.qr_code_scanner, size: 48, color: Colors.green[600]),
                SizedBox(height: 16),
                Text(
                  'QR Code Scanner',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Scan the QR code displayed by your teacher to mark attendance',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.green[600],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: QRScannerWidget(username: widget.username),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Class Schedule',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          _buildWeeklySchedule(),
        ],
      ),
    );
  }

  Widget _buildWeeklySchedule() {
    // Sample schedule data - you can replace with actual data from Firestore
    final scheduleData = [
      {'day': 'Monday', 'time': '09:00 - 10:00', 'subject': 'Mathematics', 'room': 'Room 101'},
      {'day': 'Tuesday', 'time': '10:00 - 11:00', 'subject': 'Physics', 'room': 'Lab 201'},
      {'day': 'Wednesday', 'time': '11:00 - 12:00', 'subject': 'Chemistry', 'room': 'Lab 301'},
      {'day': 'Thursday', 'time': '09:00 - 10:00', 'subject': 'Mathematics', 'room': 'Room 101'},
      {'day': 'Friday', 'time': '14:00 - 15:00', 'subject': 'Computer Science', 'room': 'Lab 401'},
    ];

    return Column(
      children: scheduleData.map((schedule) {
        return Container(
          margin: EdgeInsets.only(bottom: 12),
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
          child: Row(
            children: [
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.indigo[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule['subject']!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${schedule['day']} • ${schedule['time']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      schedule['room']!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentAttendanceList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('students')
          .where('email', isEqualTo: '${widget.username}@student.com')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: EdgeInsets.all(16),
            child: Text(
              'No recent activity',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }
        
        var studentData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        String subject = studentData['subject'] ?? 'Unknown';
        
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('attendance')
              .doc(subject)
              .collection('daily')
              .where('studentName', isEqualTo: widget.username)
              .orderBy('timestamp', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, attendanceSnapshot) {
            if (!attendanceSnapshot.hasData || attendanceSnapshot.data!.docs.isEmpty) {
              return Container(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No attendance records found',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              );
            }
            
            return Column(
              children: attendanceSnapshot.data!.docs.take(3).map((doc) {
                var data = doc.data() as Map<String, dynamic>;
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
                              'Marked Present',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[800],
                              ),
                            ),
                            Text(
                              data['date'] ?? 'Unknown date',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        subject,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildUpcomingClassesList() {
    // Sample upcoming classes - you can replace with actual data
    final upcomingClasses = [
      {'subject': 'Mathematics', 'time': 'Tomorrow, 09:00 AM', 'room': 'Room 101'},
      {'subject': 'Physics', 'time': 'Today, 02:00 PM', 'room': 'Lab 201'},
      {'subject': 'Chemistry', 'time': 'Friday, 11:00 AM', 'room': 'Lab 301'},
    ];

    return Column(
      children: upcomingClasses.take(3).map((classInfo) {
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
              Icon(Icons.schedule, color: Colors.blue[600], size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classInfo['subject']!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[800],
                      ),
                    ),
                    Text(
                      '${classInfo['time']} • ${classInfo['room']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubjectsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('students')
          .where('email', isEqualTo: '${widget.username}@student.com')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No subjects found'));
        }
        
        var studentData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        String subject = studentData['subject'] ?? 'Unknown';
        
        return Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Subjects',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: Icon(Icons.book, color: Colors.blue),
                  ),
                  title: Text(subject),
                  subtitle: Text('Current Subject'),
                  trailing: Icon(Icons.arrow_forward_ios),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttendanceTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('students')
          .where('email', isEqualTo: '${widget.username}@student.com')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No attendance data found'));
        }
        
        var studentData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        String subject = studentData['subject'] ?? 'Unknown';
        
        return Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attendance Overview',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              _buildAttendanceSummary(subject),
              SizedBox(height: 20),
              _buildDailyAttendance(subject),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttendanceSummary(String subject) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .doc(subject)
          .collection('daily')
          .where('studentName', isEqualTo: widget.username)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ));
        }
        
        int totalDays = snapshot.data?.docs.length ?? 0;
        
        return Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall Attendance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '$totalDays',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text('Days Present'),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${(totalDays / 30 * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        Text('Attendance Rate'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDailyAttendance(String subject) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Attendance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('attendance')
                      .doc(subject)
                      .collection('daily')
                      .where('studentName', isEqualTo: widget.username)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('No attendance records found'));
                    }
                    
                    final docs = snapshot.data!.docs.toList();
                    docs.sort((a, b) {
                      final at = (a.data() as Map<String, dynamic>)['timestamp'];
                      final bt = (b.data() as Map<String, dynamic>)['timestamp'];
                      final aMs = at is Timestamp ? at.millisecondsSinceEpoch : 0;
                      final bMs = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
                      return bMs.compareTo(aMs);
                    });

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var attendance = docs[index];
                        var data = attendance.data() as Map<String, dynamic>;

                        return ListTile(
                          leading: Icon(Icons.check_circle, color: Colors.green),
                          title: Text(data['date'] ?? 'Unknown Date'),
                          subtitle: Text('Time: ${data['time'] ?? 'Unknown'}'),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QRScannerWidget extends StatefulWidget {
  final String username;

  QRScannerWidget({required this.username});

  @override
  _QRScannerWidgetState createState() => _QRScannerWidgetState();
}

class _QRScannerWidgetState extends State<QRScannerWidget>
    with TickerProviderStateMixin {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  MobileScannerController? controller;
  bool attended = false;
  String? subjectName;
  late AnimationController animationController;
  bool isScannerInitialized = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller for the custom QR code animation
    animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    );

    animationController.forward();

    animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        animationController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        animationController.forward();
      }
    });

    // Initialize scanner
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    try {
      controller = MobileScannerController(
        facing: CameraFacing.back,
        detectionSpeed: DetectionSpeed.normal,
        torchEnabled: false,
      );
      
      setState(() {
        isScannerInitialized = true;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to initialize camera: $e';
        isScannerInitialized = false;
      });
      print('Scanner initialization error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (errorMessage != null)
          _buildErrorMessage()
        else if (!isScannerInitialized)
          _buildLoadingIndicator()
        else
          _buildQRView(context),
        if (isScannerInitialized && errorMessage == null) ...[
          _buildCustomQRAnimation(),
          Positioned(
            top: 150,
            child: Text(
              'Scan QR Code',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.lightBlue,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Widget to build the QR code scanner view
  Widget _buildQRView(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 300,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: MobileScanner(
          controller: controller!,
          onDetect: _onDetect,
        ),
      ),
    );
  }

  // Widget to show loading indicator
  Widget _buildLoadingIndicator() {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Initializing Camera...',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  // Widget to show error message
  Widget _buildErrorMessage() {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, color: Colors.red, size: 48),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              errorMessage ?? 'Camera Error',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializeScanner,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  // Widget to build the custom QR code animation
  Widget _buildCustomQRAnimation() {
    return Container(
      width: 300,
      height: 300,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: animationController,
            builder: (context, child) {
              return _buildRedLine(animationController.value);
            },
          ),
        ],
      ),
    );
  }

  // Widget to build the red line in the custom QR code animation
  Widget _buildRedLine(double animationValue) {
    return Positioned(
      top: 0,
      child: Container(
        width: 300,
        height: 2,
        color: Colors.red,
        margin: EdgeInsets.only(top: 300 * animationValue),
      ),
    );
  }

  // Callback when QR code is detected
  void _onDetect(BarcodeCapture capture) async {
    print("QR Detection triggered - Barcodes found: ${capture.barcodes.length}");
    
    if (attended) {
      print("Already attended, ignoring detection");
      return;
    }
    
    if (capture.barcodes.isEmpty) {
      print("No barcodes in capture");
      return;
    }
    
    final Barcode? barcode = capture.barcodes.first;
    final String? code = barcode?.rawValue;
    
    print("Raw QR code value: $code");
    print("Barcode format: ${barcode?.format}");
    
    if (code == null || code.isEmpty) {
      print("Empty or null QR code value");
      return;
    }

    print("Processing QR code: $code for user: ${widget.username}");
    
    subjectName = code;
    await _updateAttendance(subjectName);
    setState(() {
      attended = true;
    });
    
    if (mounted) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AttendanceConfirmationScreen(
            subjectName ?? '',
            widget.username,
          ),
        ),
      );
    }
  }

  Future<void> _updateAttendance(String? subjectName) async {
    try {
      if (subjectName != null) {
        String userName = widget.username;
        String currentDate = _formatDate(DateTime.now());
        String currentTime = _formatTime(DateTime.now());
        
        CollectionReference attendanceCollection =
            FirebaseFirestore.instance.collection('attendance');

        // Update overall attendance document
        await attendanceCollection.doc(subjectName).set({
          'students': FieldValue.arrayUnion([userName]),
        }, SetOptions(merge: true));

        // Update daily attendance document
        await attendanceCollection
            .doc(subjectName)
            .collection('daily')
            .doc('${currentDate}_$userName')
            .set({
          'studentName': userName,
          'date': currentDate,
          'time': currentTime,
          'timestamp': FieldValue.serverTimestamp(),
        });

        print('Attendance updated in Firestore for $userName on $currentDate at $currentTime');
      } else {
        print('Subject name is null.');
      }
    } catch (e) {
      print('Error updating attendance: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    controller?.dispose();
    animationController.dispose();
    super.dispose();
  }
}
