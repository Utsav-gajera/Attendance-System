import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:attendance_system/main.dart';
import 'package:attendance_system/firebase_options.dart';
import 'package:intl/intl.dart';

class AdminHomeScreen extends StatefulWidget {
  @override
  _AdminHomeScreenState createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final TextEditingController _teacherEmailController = TextEditingController();
  final TextEditingController _teacherPasswordController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.deepPurple[700],
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Admin Dashboard', 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('System Administration', 
                style: TextStyle(fontSize: 12, color: Colors.deepPurple[100])),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            child: CircleAvatar(
              backgroundColor: Colors.deepPurple[100],
              child: IconButton(
                icon: Icon(Icons.person, color: Colors.deepPurple[700], size: 20),
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
            selectedItemColor: Colors.deepPurple[700],
            unselectedItemColor: Colors.grey[600],
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people_outlined),
                activeIcon: Icon(Icons.people),
                label: 'Teachers',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.school_outlined),
                activeIcon: Icon(Icons.school),
                label: 'Students',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.analytics_outlined),
                activeIcon: Icon(Icons.analytics),
                label: 'Reports',
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
        return _buildTeachersTab();
      case 2:
        return _buildStudentsTab();
      case 3:
        return _buildReportsTab();
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
          _buildSystemOverviewGrid(),
          SizedBox(height: 16),
          _buildRecentActivityCard(),
          SizedBox(height: 16),
          _buildQuickActionsCard(),
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
          colors: [Colors.deepPurple[400]!, Colors.deepPurple[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
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
                child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, Administrator!',
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
            'Manage your attendance system',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          Text(
            'Monitor teachers, students, and system performance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemOverviewGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Overview',
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
              child: _buildOverviewCard(
                'Total Teachers',
                Icons.people,
                Colors.teal,
                _buildTeacherCountWidget(),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildOverviewCard(
                'Total Students',
                Icons.school,
                Colors.blue,
                _buildStudentCountWidget(),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                'Active Subjects',
                Icons.book,
                Colors.orange,
                _buildSubjectCountWidget(),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildOverviewCard(
                'Today\'s Attendance',
                Icons.check_circle,
                Colors.green,
                Text('125', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewCard(String title, IconData icon, Color color, Widget valueWidget) {
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

  Widget _buildTeacherCountWidget() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('teachers').snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.data?.docs.length ?? 0;
        return Text(
          '$count',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        );
      },
    );
  }

  Widget _buildStudentCountWidget() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('students').snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.data?.docs.length ?? 0;
        return Text(
          '$count',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        );
      },
    );
  }

  Widget _buildSubjectCountWidget() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('teachers').snapshots(),
      builder: (context, snapshot) {
        Set<String> subjects = {};
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['subject'] != null) {
              subjects.add(data['subject']);
            }
          }
        }
        return Text(
          '${subjects.length}',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
              Icon(Icons.history, color: Colors.deepPurple[700], size: 24),
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
          _buildRecentActivityList(),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
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
              Icon(Icons.flash_on, color: Colors.deepPurple[700], size: 24),
              SizedBox(width: 8),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  'Add Teacher',
                  Icons.person_add,
                  Colors.teal,
                  () => setState(() => _selectedIndex = 1),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  'View Reports',
                  Icons.assessment,
                  Colors.orange,
                  () => setState(() => _selectedIndex = 3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(String title, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(title),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildTeachersTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Teacher Management',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          _buildAddTeacherSection(),
          SizedBox(height: 20),
          _buildTeachersList(),
        ],
      ),
    );
  }

  Widget _buildStudentsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Student Management',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          _buildStudentsList(),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Reports',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          _buildAttendanceReports(),
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
              Icon(Icons.admin_panel_settings, color: Colors.deepPurple[700]),
              SizedBox(width: 8),
              Text('Admin Profile'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email: ${FirebaseAuth.instance.currentUser?.email ?? "Not available"}'),
              SizedBox(height: 8),
              Text('Role: System Administrator'),
              SizedBox(height: 8),
              Text('Access: Full System Control'),
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

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.admin_panel_settings, size: 40, color: Colors.red),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
                ),
                Text(
                  'Manage teachers and subjects',
                  style: TextStyle(color: Colors.red[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTeacherSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add New Teacher',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _teacherEmailController,
              decoration: InputDecoration(
                labelText: 'Teacher Email',
                hintText: 'teacher@teacher.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _teacherPasswordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            SizedBox(height: 12),
            TextField(
              controller: _subjectController,
              decoration: InputDecoration(
                labelText: 'Subject',
                hintText: 'e.g., Mathematics, Physics',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.book),
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addTeacher,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Add Teacher'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeachersList() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Teachers List',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('teachers').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Text('No teachers found');
                }
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var teacher = snapshot.data!.docs[index];
                    var data = teacher.data() as Map<String, dynamic>;
                    
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red[100],
                          child: Icon(Icons.person, color: Colors.red),
                        ),
                        title: Text(data['email'] ?? 'Unknown'),
                        subtitle: Text('Subject: ${data['subject'] ?? 'Not assigned'}'),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteTeacher(teacher.id),
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

  Future<void> _addTeacher() async {
    if (_teacherEmailController.text.isEmpty ||
        _teacherPasswordController.text.isEmpty ||
        _subjectController.text.isEmpty) {
      _showError('Please fill all fields');
      return;
    }

    final String email = _teacherEmailController.text.trim().toLowerCase();
    final String password = _teacherPasswordController.text.trim();
    final String subject = _subjectController.text.trim();

    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (!email.endsWith('@teacher.com')) {
      _showError('Teacher email must end with @teacher.com');
      return;
    }

    try {
      // Use a secondary Firebase app to avoid switching the admin session
      FirebaseApp secondaryApp;
      try {
        secondaryApp = Firebase.app('admin_worker');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'admin_worker',
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      final FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // Try to create the teacher auth user (secondary app keeps admin logged in)
      try {
        await secondaryAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          _showError('Email already in use. Choose another email or reset password for this user.');
          return;
        } else {
          rethrow; // real failure, bubble up to show error
        }
      }

      // Upsert teacher record in Firestore using email as the document id
      await _firestore.collection('teachers').doc(email).set({
        'email': email,
        'subject': subject,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _showSuccess('Teacher added successfully!');
      
      // Clear form
      _teacherEmailController.clear();
      _teacherPasswordController.clear();
      _subjectController.clear();
      
    } catch (e) {
      print('Error adding teacher: $e');
      _showError('Failed to add teacher: ${e.toString()}');
    }
  }

  Future<void> _deleteTeacher(String teacherId) async {
    try {
      // Delete from Firestore (teacherId is the doc id; we use email as id)
      await _firestore.collection('teachers').doc(teacherId).delete();
      
      // Delete from Firebase Auth (optional - you might want to keep the account)
      // await _auth.deleteUser(teacherId);
      
      _showSuccess('Teacher deleted successfully!');
    } catch (e) {
      print('Error deleting teacher: $e');
      _showError('Failed to delete teacher');
    }
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

  Widget _buildRecentActivityList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('attendance').orderBy('timestamp', descending: true).limit(5).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: EdgeInsets.all(16),
            child: Text(
              'No recent activity found',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          );
        }
        
        return Column(
          children: snapshot.data!.docs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            var timestamp = data['timestamp']?.toDate() ?? DateTime.now();
            var studentEmail = data['studentEmail'] ?? 'Unknown';
            var subject = data['subject'] ?? 'Unknown';
            var status = data['status'] ?? 'present';
            
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: status == 'present' ? Colors.green[100] : Colors.red[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      status == 'present' ? Icons.check : Icons.close,
                      color: status == 'present' ? Colors.green : Colors.red,
                      size: 16,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentEmail,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '$subject - ${status.toUpperCase()}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    DateFormat('MMM d, HH:mm').format(timestamp),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
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

  Widget _buildStudentsList() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Students',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'View Only',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('students').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No students registered yet',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  );
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
                          child: Icon(Icons.school, color: Colors.blue),
                        ),
                        title: Text(data['email'] ?? 'Unknown'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Student ID: ${data['studentId'] ?? 'N/A'}'),
                            if (data['enrolledSubjects'] != null)
                              Text('Subjects: ${(data['enrolledSubjects'] as List).join(', ')}'),
                          ],
                        ),
                        trailing: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.green[800],
                              fontSize: 12,
                            ),
                          ),
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

  Widget _buildAttendanceReports() {
    return Column(
      children: [
        _buildReportCard(
          'Today\'s Attendance Summary',
          Icons.today,
          Colors.blue,
          _buildTodayAttendanceReport(),
        ),
        SizedBox(height: 16),
        _buildReportCard(
          'Subject-wise Attendance',
          Icons.subject,
          Colors.green,
          _buildSubjectWiseReport(),
        ),
        SizedBox(height: 16),
        _buildReportCard(
          'Weekly Attendance Trends',
          Icons.trending_up,
          Colors.orange,
          _buildWeeklyTrendsReport(),
        ),
      ],
    );
  }

  Widget _buildReportCard(String title, IconData icon, Color color, Widget content) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildTodayAttendanceReport() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('attendance')
          .where('timestamp', isGreaterThan: DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ))
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }
        
        int total = snapshot.data?.docs.length ?? 0;
        int present = snapshot.data?.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'present';
        }).length ?? 0;
        
        double percentage = total > 0 ? (present / total) * 100 : 0;
        
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('Total', '$total', Colors.blue),
                _buildStatColumn('Present', '$present', Colors.green),
                _buildStatColumn('Absent', '${total - present}', Colors.red),
                _buildStatColumn('Rate', '${percentage.toStringAsFixed(1)}%', Colors.orange),
              ],
            ),
            SizedBox(height: 12),
            LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                percentage >= 75 ? Colors.green : percentage >= 50 ? Colors.orange : Colors.red,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubjectWiseReport() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('teachers').snapshots(),
      builder: (context, teacherSnapshot) {
        if (!teacherSnapshot.hasData) {
          return CircularProgressIndicator();
        }
        
        Map<String, String> subjectTeacherMap = {};
        for (var doc in teacherSnapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          if (data['subject'] != null) {
            subjectTeacherMap[data['subject']] = data['email'];
          }
        }
        
        return Column(
          children: subjectTeacherMap.entries.map((entry) {
            return Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'by ${entry.value}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('attendance')
                        .where('subject', isEqualTo: entry.key)
                        .where('timestamp', isGreaterThan: DateTime(
                          DateTime.now().year,
                          DateTime.now().month,
                          DateTime.now().day,
                        ))
                        .snapshots(),
                    builder: (context, snapshot) {
                      int total = snapshot.data?.docs.length ?? 0;
                      int present = snapshot.data?.docs.where((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        return data['status'] == 'present';
                      }).length ?? 0;
                      
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: present == total && total > 0 ? Colors.green[100] : Colors.orange[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$present/$total',
                          style: TextStyle(
                            color: present == total && total > 0 ? Colors.green[800] : Colors.orange[800],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildWeeklyTrendsReport() {
    return Container(
      height: 200,
      child: Column(
        children: [
          Text(
            'Weekly attendance trends would be displayed here with charts',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTrendDay('Mon', 85),
              _buildTrendDay('Tue', 92),
              _buildTrendDay('Wed', 78),
              _buildTrendDay('Thu', 88),
              _buildTrendDay('Fri', 95),
              _buildTrendDay('Sat', 82),
              _buildTrendDay('Sun', 90),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendDay(String day, int percentage) {
    return Column(
      children: [
        Container(
          height: 100,
          width: 30,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                height: percentage.toDouble(),
                width: 30,
                decoration: BoxDecoration(
                  color: percentage >= 80 ? Colors.green : percentage >= 60 ? Colors.orange : Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Text(day, style: TextStyle(fontSize: 12)),
        Text('$percentage%', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
