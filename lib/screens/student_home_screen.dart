import 'package:flutter/material.dart';
import 'package:attendance_system/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'attendance_confirmation_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  final String username;

  StudentHomeScreen(this.username);

  @override
  _StudentHomeScreenState createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _selectedIndex = 0;

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
      appBar: AppBar(
        title: Text('Student Home - ${widget.username}'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan QR',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Subjects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Attendance',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return Center(child: QRScannerWidget(username: widget.username));
      case 1:
        return _buildSubjectsTab();
      case 2:
        return _buildAttendanceTab();
      default:
        return Center(child: QRScannerWidget(username: widget.username));
    }
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
