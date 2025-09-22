import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../screens/attendance_confirmation_screen.dart';
import '../services/attendance_service.dart';
import '../utils/error_handler.dart';
import '../utils/animations.dart';

class QRScannerWidget extends StatefulWidget {
  final String studentUsername;
  final String studentEmail;

  const QRScannerWidget({
    Key? key,
    required this.studentUsername,
    required this.studentEmail,
  }) : super(key: key);

  @override
  State<QRScannerWidget> createState() => _QRScannerWidgetState();
}

class _QRScannerWidgetState extends State<QRScannerWidget>
    with TickerProviderStateMixin {
  MobileScannerController? controller;
  bool isScannerInitialized = false;
  String? errorMessage;
  bool attended = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _animationController.repeat();
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    try {
      controller = MobileScannerController(
        facing: CameraFacing.back,
        detectionSpeed: DetectionSpeed.noDuplicates,
        torchEnabled: false,
      );

      await Future.delayed(Duration(milliseconds: 500));
      
      if (mounted) {
        setState(() {
          isScannerInitialized = true;
          errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to initialize camera: ${e.toString()}';
          isScannerInitialized = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (errorMessage != null)
            _buildErrorMessage()
          else if (!isScannerInitialized)
            _buildLoadingIndicator()
          else
            _buildQRView(),
          
          if (isScannerInitialized && errorMessage == null)
            _buildScannerOverlay(),
        ],
      ),
    );
  }

  Widget _buildQRView() {
    return Container(
      width: 300,
      height: 300,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: MobileScanner(
          controller: controller!,
          onDetect: _onDetect,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.blue),
          SizedBox(height: 20),
          Text('Initializing Camera...', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
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
            onPressed: _retryScanner,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Stack(
      children: [
        Center(
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        color: Colors.red,
                        margin: EdgeInsets.only(top: 296 * _animationController.value),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        Positioned(
          top: 50,
          left: 0,
          right: 0,
          child: Text(
            'Scan QR Code',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(offset: Offset(0, 1), blurRadius: 3)],
            ),
          ),
        ),
      ],
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    if (attended || capture.barcodes.isEmpty) return;

    final barcode = capture.barcodes.first;
    final String? qrCode = barcode.rawValue;

    if (qrCode == null || qrCode.isEmpty) return;

    setState(() {
      attended = true;
    });

    try {
      final success = await AttendanceService.markAttendanceWithQR(
        studentEmail: widget.studentEmail,
        studentName: widget.studentUsername,
        qrCode: qrCode,
      );

      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AttendanceConfirmationScreen(
              qrCode,
              widget.studentUsername,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          attended = false;
        });
        final msg = e.toString();
        if (msg.contains('expired')) {
          ErrorHandler.showWarning(context, 'QR code expired. Ask your teacher to generate a new one.');
        } else if (msg.contains('no longer active')) {
          ErrorHandler.showWarning(context, 'This QR session is not active any more.');
        } else if (msg.contains('already marked')) {
          ErrorHandler.showInfo(context, 'You already marked attendance for this subject today.');
        } else {
          ErrorHandler.showError(context, 'Could not mark attendance: $msg');
        }
      }
    }
  }

  void _retryScanner() async {
    setState(() {
      errorMessage = null;
      isScannerInitialized = false;
    });
    
    controller?.dispose();
    controller = null;
    await _initializeScanner();
  }

  @override
  void dispose() {
    _animationController.dispose();
    controller?.dispose();
    super.dispose();
  }
}