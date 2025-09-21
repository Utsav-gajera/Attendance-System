import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:attendance_system/main.dart';
import 'package:attendance_system/firebase_options.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 20),
            _buildAddTeacherSection(),
            SizedBox(height: 20),
            _buildTeachersList(),
          ],
        ),
      ),
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
}
