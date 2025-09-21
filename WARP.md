# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is a Flutter mobile application for attendance management in educational institutions. The system uses Firebase for authentication and Cloud Firestore for data storage. It features role-based access with three user types: students, teachers, and admins. Students scan QR codes to mark attendance, while teachers generate QR codes and view attendance records.

## Common Development Commands

### Flutter Development
```bash
# Install dependencies
flutter pub get

# Run the app in debug mode
flutter run

# Run on specific device
flutter run -d <device-id>

# Build for Android
flutter build apk

# Build for Android App Bundle
flutter build appbundle

# Run tests
flutter test

# Analyze code
flutter analyze

# Clean build
flutter clean

# Get Flutter devices
flutter devices
```

### Testing and Debugging
```bash
# Run widget tests
flutter test test/widget_test.dart

# Run in debug mode with hot reload
flutter run --debug

# Run in release mode
flutter run --release

# Profile mode (for performance analysis)
flutter run --profile
```

### Firebase Setup Commands
```bash
# Initialize Firebase (if needed)
firebase init

# Deploy Firebase rules
firebase deploy --only firestore:rules

# Login to Firebase
firebase login
```

### QR Code Generation for Testing
```bash
# Generate test QR codes using the included Python script
python generate_test_qr.py

# Or with Python 3 explicitly
python3 generate_test_qr.py
```

## Code Architecture

### Authentication Flow
- **Entry point**: `main.dart` with `LoginPage` widget
- **Role-based routing**: Email domain determines user role:
  - `@student.com` → `StudentHomeScreen`
  - `@teacher.com` → `TeacherHomeScreen` 
  - `@admin.com` → `AdminHomeScreen`
- **Firebase Auth**: Used for secure login/signup with email/password

### Data Model
- **Firestore Collections**:
  - `students`: Student profiles with subject assignments
  - `attendance/{subject}/daily`: Daily attendance records per subject
  - Each teacher's email prefix becomes their subject name (e.g., `maths@teacher.com` teaches "maths")

### Screen Architecture
- **Student Flow**: QR scanning → confirmation → attendance tracking
- **Teacher Flow**: QR generation → student management → attendance viewing
- **Admin Flow**: System overview and management capabilities

### Key Components
- **QR Scanner**: Uses `mobile_scanner` package for real-time QR code detection
- **QR Generation**: Uses `qr_flutter` to generate subject-specific QR codes
- **Calendar Integration**: `table_calendar` for attendance date selection
- **State Management**: Flutter's built-in `setState` (no BLoC pattern actively used despite dependency)

### Firebase Integration
- **Authentication**: Email/password with role-based access control
- **Firestore**: Real-time data synchronization for attendance records
- **Configuration**: Platform-specific setup in `firebase_options.dart`

## Important Files and Directories

### Core Application
- `lib/main.dart`: App entry point and login logic
- `lib/firebase_options.dart`: Firebase configuration
- `lib/screens/`: All UI screens organized by role

### Configuration Files  
- `pubspec.yaml`: Flutter dependencies and project metadata
- `analysis_options.yaml`: Dart linting configuration
- `android/build.gradle`: Android build configuration with Firebase support

### Development Utilities
- `generate_test_qr.py`: Python script for generating test QR codes
- `test/widget_test.dart`: Basic widget testing setup

## Dependencies Notes

### Key Packages
- **Firebase**: `firebase_core`, `firebase_auth`, `cloud_firestore`
- **QR Features**: `mobile_scanner`, `qr_flutter` 
- **UI Components**: `table_calendar` for calendar views
- **State Management**: `flutter_bloc`, `hydrated_bloc` (present but not actively used)

### Android-Specific
- Requires Google Services plugin for Firebase
- AGP 8+ namespace workaround included for QR scanner compatibility
- Minimum SDK and compile SDK specified in app-level build.gradle

## Development Setup Requirements

### Prerequisites
- Flutter SDK (>=3.3.0 <4.0.0)
- Android Studio/Xcode for device testing
- Firebase project with Authentication and Firestore enabled
- Python 3 (for QR code generation utility)

### Firebase Configuration
- Download `google-services.json` for Android (`android/app/`)
- Download `GoogleService-Info.plist` for iOS (`ios/Runner/`)
- Enable Email/Password authentication in Firebase Console
- Set up Firestore database with appropriate security rules

### Email Domain Setup
The system relies on specific email domains:
- Students: `username@student.com`
- Teachers: `subject@teacher.com` (e.g., `maths@teacher.com`)
- Admins: `username@admin.com`

## Testing Strategy

### QR Code Testing
1. Run `python generate_test_qr.py` to create test QR codes
2. Print or display QR codes on screen (minimum 2x2 cm)
3. Use student scanner to test attendance marking
4. QR codes contain plain subject names (e.g., "Maths", "Physics")

### User Role Testing
Create test accounts for each role with appropriate email domains to verify role-based navigation and permissions.