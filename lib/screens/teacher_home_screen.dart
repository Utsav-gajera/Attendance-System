import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'attendance_list_widget.dart';
import 'package:attendance_system/main.dart';
import 'package:attendance_system/firebase_options.dart';

class TeacherHomeScreen extends StatefulWidget {
  @override
  _TeacherHomeScreenState createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  String? _subjectName;
  bool _showQRCode = false;
  int _selectedIndex = 0;
  final TextEditingController _studentEmailController = TextEditingController();
  final TextEditingController _studentPasswordController = TextEditingController();
  final TextEditingController _studentNameController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _extractSubjectName();
  }

  void _extractSubjectName() {
    User? user = FirebaseAuth.instance.currentUser;
    String? teacherEmail = user?.email;
    
    if (teacherEmail != null) {
      List<String> parts = teacherEmail.split('@');
      if (parts.length == 2) {
        setState(() {
          _subjectName = parts[0];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Teacher Home - $_subjectName'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code),
            onPressed: () {
              setState(() {
                _showQRCode = !_showQRCode;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: _buildBody(context),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Students',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
        ],
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
        return _buildHomeTab();
      case 1:
        return _buildStudentsTab();
      case 2:
        return _buildCalendarTab();
      default:
        return _buildHomeTab();
    }
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
            data: _subjectName!,
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
    if (_subjectName == null) {
      return Center(
        child: Text('Subject name not found.'),
      );
    }

    return AttendanceListWidget(subjectName: _subjectName!);
  }

  Widget _buildAddStudentSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add New Student',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _studentNameController,
              decoration: InputDecoration(
                labelText: 'Student Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            SizedBox(height: 12),
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
            TextField(
              controller: _studentPasswordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addStudent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text('Add Student'),
              ),
            ),
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
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('students')
                  .where('subject', isEqualTo: _subjectName)
                  .snapshots(),
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
                    var student = snapshot.data!.docs[index];
                    var data = student.data() as Map<String, dynamic>;
                    
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: Icon(Icons.person, color: Colors.blue),
                        ),
                        title: Text(data['name'] ?? 'Unknown'),
                        subtitle: Text(data['email'] ?? 'No email'),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteStudent(student.id),
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
                  .doc(_subjectName)
                  .collection('daily')
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

  Future<void> _addStudent() async {
    if (_studentNameController.text.isEmpty ||
        _studentEmailController.text.isEmpty ||
        _studentPasswordController.text.isEmpty) {
      _showError('Please fill all fields');
      return;
    }

    if (!_studentEmailController.text.endsWith('@student.com')) {
      _showError('Student email must end with @student.com');
      return;
    }

    final String studentEmail = _studentEmailController.text.trim().toLowerCase();
    final String studentPassword = _studentPasswordController.text.trim();
    if (studentPassword.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    try {
      // Use a secondary Firebase app so the teacher session is not replaced
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

      // Try to create the student auth user
      try {
        await secondaryAuth.createUserWithEmailAndPassword(
          email: studentEmail,
          password: studentPassword,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          _showError('Email already in use. Ask the student to reset password or choose another email.');
          return;
        } else {
          rethrow;
        }
      }

      // Only write Firestore if Auth user was created successfully
      await _firestore.collection('students').doc(studentEmail).set({
        'name': _studentNameController.text,
        'email': studentEmail,
        'subject': _subjectName,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _showSuccess('Student added successfully!');
      
      // Clear form
      _studentNameController.clear();
      _studentEmailController.clear();
      _studentPasswordController.clear();
      
    } catch (e) {
      print('Error adding student: $e');
      _showError('Failed to add student: ${e.toString()}');
    }
  }

  Future<void> _deleteStudent(String studentId) async {
    try {
      await _firestore.collection('students').doc(studentId).delete();
      _showSuccess('Student deleted successfully!');
    } catch (e) {
      print('Error deleting student: $e');
      _showError('Failed to delete student');
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}
