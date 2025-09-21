import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/teacher_home_screen.dart';
import 'screens/student_home_screen.dart';
import 'screens/admin_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with better error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      // App already initialized, continue
      print('Firebase app already initialized');
    } else {
      print('Firebase initialization error: ${e.message}');
      rethrow;
    }
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance System',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Firebase Authentication instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _isSignUp = false;
  bool _isLoading = false;

  Future<void> _signIn() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final String email = _emailController.text.trim().toLowerCase();
      final String password = _passwordController.text;
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('Signed in: ${userCredential.user?.email}');
      final String signedInEmail = (userCredential.user?.email ?? '').toLowerCase();
      String username = signedInEmail.split('@')[0];

      if (signedInEmail.endsWith('@admin.com')) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminHomeScreen(),
          ),
        );
      } else if (signedInEmail.endsWith('@teacher.com')) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TeacherHomeScreen(),
          ),
        );
      } else if (signedInEmail.endsWith('@student.com')) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StudentHomeScreen(username),
          ),
        );
      } else {
        _showError('Please use a valid admin, teacher or student email address.');
      }
    } catch (e) {
      print('Error signing in: $e');
      String errorMessage = 'Invalid email or password. Please try again.';
      _showError(errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signUp() async {
    if (_isLoading) return;
    
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match.');
      return;
    }
    
    if (_passwordController.text.length < 6) {
      _showError('Password must be at least 6 characters long.');
      return;
    }
    
    final String email = _emailController.text.trim().toLowerCase();
    if (!email.endsWith('@teacher.com') && 
        !email.endsWith('@admin.com')) {
      _showError('Email must end with @teacher.com or @admin.com');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );

      print('Teacher signed up: ${userCredential.user?.email}');
      
      _showSuccess('Teacher account created successfully! Please sign in.');
      
      setState(() {
        _isSignUp = false;
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
      });
      
    } catch (e) {
      print('Error signing up: $e');
      String errorMessage = 'Failed to create account. Please try again.';
      if (e.toString().contains('email-already-in-use')) {
        errorMessage = 'This email is already registered.';
      }
      _showError(errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(''),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16.0),
          child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.school,
              size: 100,
              color: Colors.blue,
            ),
            SizedBox(height: 20),
            Text(
              'Attendance System',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: _isSignUp ? 'teacher@teacher.com or admin@admin.com' : 'user@student.com, user@teacher.com or admin@admin.com',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            if (_isSignUp) ...[
              SizedBox(height: 10),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            SizedBox(height: 16.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : (_isSignUp ? _signUp : _signIn),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isLoading 
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(_isSignUp ? 'Sign Up' : 'Login'),
              ),
            ),
            SizedBox(height: 10),
            TextButton(
              onPressed: () {
                setState(() {
                  _isSignUp = !_isSignUp;
                  _emailController.clear();
                  _passwordController.clear();
                  _confirmPasswordController.clear();
                });
              },
              child: Text(
                _isSignUp 
                  ? 'Already have an account? Login'
                  : 'Need a teacher/admin account? Sign Up',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            if (_isSignUp) ...[
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  children: [
                    Text(
                      'Sign Up Info:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Email must end with @teacher.com or @admin.com\n• Password must be at least 6 characters\n• Examples: maths@teacher.com, admin@admin.com',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
