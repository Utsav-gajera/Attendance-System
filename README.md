## Description

The Attendance System is a mobile application developed using **Flutter** and **Firebase** that simplifies attendance management in educational institutions. Users can log in with their registered email addresses through Firebase Authentication and are redirected to specific pages based on their roles—students or teachers.

### Key Features

- **User Authentication:** Secure login using registered email addresses via Firebase Authentication.
- **Role-Based Access:** Students and teachers have different interfaces tailored to their needs.
- **QR Code Scanning:** Students can easily mark their attendance by scanning QR codes associated with their classes. This feature ensures a quick, secure, and efficient way to record attendance.
- **QR Code Generation:** Teachers can generate QR codes for each subject, allowing students to scan them to mark their attendance. The QR codes are tied to the subject names.(u can use a script to generate qr_images based on subject name)
- **Attendance Tracking for Teachers:** Teachers can view a comprehensive list of students who have attended their classes, making it easier to manage attendance records.

Here are some screenshots of the application showcasing its UI and key functionality:

<table>
  <tr>
    <td><img src="assets/screenshots/Screenshot_1.jpg" alt="Login Page" width="300"/></td>
    <td><img src="assets/screenshots/Screenshot_2.jpg" alt="Scan Page" width="300"/></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/Screenshot_3.jpg" alt="Confirmation Page" width="300"/></td>
    <td><img src="assets/screenshots/Screenshot_4.jpg" alt="Student List Page" width="300"/></td>
  </tr>
</table>

## Installation

### Prerequisites

- [Flutter](https://flutter.dev/docs/get-started/install) installed on your machine.
- A Firebase project set up for authentication and database.

### Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Utsav-gajera/Attendance-System
   ```

## Installation

### Prerequisites

Before starting, make sure you have the following installed:

- [Flutter](https://flutter.dev/docs/get-started/install) installed on your machine.
- A Firebase project set up for authentication and database services.

### Steps

1. **Clone the repository:** First, clone the project repository from GitHub to your local machine:  
   `git clone https://github.com/Utsav-gajera/Attendance-System.git`

2. **Navigate to the project directory:** Move into the project directory using the following command:  
   `cd Attendance-System`

3. **Install dependencies:** Run the following command to install all necessary Flutter dependencies:  
   `flutter pub get`

4. **Set up Firebase:** You'll need to set up Firebase for authentication and database services.  
   a. **Create a Firebase Project:** Go to [Firebase Console](https://console.firebase.google.com/), click on **Add Project**, and follow the instructions to create a new project.  
   b. **Enable Firebase Authentication:** In your Firebase Console, navigate to **Authentication** > **Sign-in method**, and enable the **Email/Password** provider.  
   c. **Set up Cloud Firestore:** In Firebase Console, go to **Firestore Database**, and create a new Firestore database. Start in "Test Mode" for development, but ensure you configure security rules later for production.  
   d. **Download Firebase Configuration Files:**

   - **For Android:** Download the `google-services.json` file from Firebase Console and place it in the `android/app` directory of your Flutter project.
   - **For iOS:** Download the `GoogleService-Info.plist` file and place it in the `ios/Runner` directory.

5. **Configure Firebase in Your Flutter Project:** In your `pubspec.yaml` file, ensure that the following dependencies are included:

   ```yaml
   dependencies:
     firebase_core: latest_version
     firebase_auth: latest_version
     cloud_firestore: latest_version
     qr_code_scanner: latest_version
   ```

Then run:
flutter pub get

6. **Run the app:** Once everything is set up, run the application on an emulator or physical device using:
   flutter run

- Ensure your Firebase project is correctly linked, and you can now start using the app!

## Usage

Students: Log in and scan the class QR code to mark attendance.

Teachers: Log in to view the list of students who have attended.

## Contributing

If you'd like to contribute to this project, feel free to submit pull requests or report issues.
