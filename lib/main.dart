import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/teacher_home_screen.dart';
import 'screens/student_home_screen.dart';
import 'screens/admin_home_screen.dart';
import 'utils/error_handler.dart';
import 'utils/validators.dart';
import 'services/offline_service.dart';
import 'services/accessibility_service.dart';

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

  // Initialize services
  try {
    await OfflineService().initialize();
    await AccessibilityService().initialize();
  } catch (e) {
    print('Service initialization error: $e');
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final AccessibilityService _accessibilityService = AccessibilityService();
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance System',
      theme: _accessibilityService.getAccessibleTheme(ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      )),
      home: ConnectionStatusWidget(
        child: AuthWrapper(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Authentication wrapper to handle persistent login sessions
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                ],
              ),
            ),
          );
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          // User is logged in, navigate to appropriate home screen
          return UserHomeNavigator(user: snapshot.data!);
        } else {
          // User is not logged in, show login page
          return LoginPage();
        }
      },
    );
  }
}

// Navigator to direct users to their appropriate home screens
class UserHomeNavigator extends StatelessWidget {
  final User user;
  
  const UserHomeNavigator({required this.user});
  
  @override
  Widget build(BuildContext context) {
    final String email = user.email?.toLowerCase() ?? '';
    
    if (email.endsWith('@admin.com')) {
      return AdminHomeScreen();
    } else if (email.endsWith('@teacher.com')) {
      return TeacherHomeScreen();
    } else if (email.endsWith('@student.com')) {
      String username = email.split('@')[0];
      return StudentHomeScreen(username);
    } else {
      // Invalid user type, sign out and return to login
      FirebaseAuth.instance.signOut();
      return LoginPage();
    }
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Firebase Authentication instance
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;

  Future<void> _signIn() async {
    if (_isLoading || !FormValidator.validateForm(_formKey)) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });

    await ErrorHandler.handleAsyncOperation(
      context,
      () async {
        final String email = Validators.sanitizeEmail(_emailController.text);
        final String password = _passwordController.text;
        
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        print('Successfully signed in: $email');
      },
      loadingMessage: 'Signing in...',
    );

    setState(() {
      _isLoading = false;
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 60),
              // Logo and Title
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.school,
                  size: 80,
                  color: Colors.blue[700],
                ),
              ),
              SizedBox(height: 32),
              Text(
                'Attendance System',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Please sign in to continue',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 48),
              // Login Form
              LoadingOverlay(
                isLoading: _isLoading,
                message: 'Signing in...',
                child: Container(
                  padding: EdgeInsets.all(24),
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        AccessibleTextField(
                          labelText: 'Email Address',
                          hintText: 'user@student.com, user@teacher.com, admin@admin.com',
                          controller: _emailController,
                          validator: Validators.validateEmail,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email_outlined,
                          semanticLabel: 'Email address field',
                        ),
                        SizedBox(height: 20),
                        AccessibleTextField(
                          labelText: 'Password',
                          controller: _passwordController,
                          validator: Validators.validatePassword,
                          obscureText: true,
                          prefixIcon: Icons.lock_outline,
                          semanticLabel: 'Password field',
                        ),
                        SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: AccessibleButton(
                            text: 'Login',
                            onPressed: _isLoading ? null : _signIn,
                            backgroundColor: Colors.blue[700],
                            semanticLabel: 'Login button',
                            tooltip: 'Sign in to your account',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 32),
              // Info Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Account Types:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Students: yourname@student.com\n• Teachers: yourname@teacher.com\n• Admin: admin@admin.com',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[700],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
