# 🎓 SmartCampus ID (Flutter + Firebase)

A production-ready attendance management app for Admins, Teachers, and Students with QR-based marking, analytics, and robust data model. This README reflects the current architecture and behavior of the codebase.

## Highlights

- Multi-role app: Admin, Teacher, Student (email domain based)
  - Admin: any email ending with `@admin.com`
  - Teacher: `@teacher.com`
  - Student: `@student.com`
- Many-to-many enrollment between students and subjects
- Reliable QR attendance with a configurable validity window (default: 90 minutes)
- Real-time Firestore sync + offline queue (with fallback collection)
- Full cascade-deletion for all remove operations (see “Data lifecycle”)

## Data model (Firestore)

Collections and mirrors used by the app:

```
attendance/
├── {subjectCode}/
│   └── records/
│       └── {recordId}  // recordId: {studentLocal}_{subjectCode}_{yyyy-MM-dd}

students/
├── {studentEmail}/
│   ├── attendance/
│   │   └── {recordId}
│   └── subjects/
│       └── {subjectCode}

teachers/
├── {teacherEmail}/
│   └── attendance/
│       └── {recordId}

subject_enrollments/
├── {subjectCode}/
│   └── students/
│       └── {studentEmail}

student_enrollments/
├── {studentEmail}

qr_sessions/
├── {subjectCode}_{yyyy-MM-dd}

daily_attendance/
├── {yyyy-MM-dd}/
│   └── records/{recordId}

attendance_unified   // read-only fallback used by offline queue
```

Notes
- The app prefers single-field time-range queries over composite indexes.
- We explicitly avoided collectionGroup queries in destructive paths to remove the need for manual indexes.

## Data lifecycle (create, update, delete)

- Mark attendance
  - Writes to 4 places atomically via a batch:
    1) attendance/{subject}/records/{recordId}
    2) students/{email}/attendance/{recordId}
    3) teachers/{email}/attendance/{recordId}
    4) daily_attendance/{date}/records/{recordId}
  - Also upserts students/{email}/subjects/{subjectCode} stats.

- Enroll/Unenroll
  - Enroll updates both mirrors:
    - students/{email}/subjects/{code}
    - subject_enrollments/{code}/students/{email}
  - student_enrollments/{email} remains a synced summary document.

- Cascade deletes (implemented everywhere)
  - Teacher → “Remove student from subject”
    - Deletes all attendance for that student in that subject from all mirrors (subject, student, teacher, daily).
    - Updates both enrollment mirrors and the summary document.
  - Admin → “Delete student completely”
    - Deletes all their attendance from every mirror, removes enrollment mirrors and summary doc, removes the student document and attempts Auth deletion (see Security Notice).
  - Admin → “Delete teacher”
    - For each subject owned by the teacher: deletes all records + mirrors, removes rosters and student subject entries, deletes the subject and enrollment containers, then deletes teacher subcollections, document, and attempts Auth deletion.

## QR sessions

- When a teacher generates a QR, a session is saved in `qr_sessions/{subjectCode}_{yyyy-MM-dd}` with:
  - teacherEmail, teacherName, subjectCode
  - generatedAt, validUntil (= now + 90 minutes), isActive
- Scanner validates session and prevents duplicates for the day.

## Getting started

Clone
```bash
git clone https://github.com/Utsav-gajera/SmartCampus-ID.git
cd SmartCampus-ID
```

Prerequisites
- Flutter SDK (>= 3.3.0)
- Firebase project with Auth + Firestore enabled
- Android device (recommended for scanning tests)

Setup
1) Install dependencies
```bash
flutter pub get
```
2) Firebase config
- Place `android/app/google-services.json`
- Place `ios/Runner/GoogleService-Info.plist` (when building iOS)
- Ensure `lib/firebase_options.dart` matches your Firebase project (flutterfire configure or your generated file)
3) Run
```bash
flutter run -d <device-id>
```

Notes
- Android package: `com.example.smartcampusid`
- iOS bundle id: `com.example.smartcampusid`
- If you change these IDs, add new apps in Firebase and replace both config files accordingly.

## Troubleshooting

- Android Gradle Plugin / Kotlin warnings
  - The project is configured with AGP 8.6.0 and Kotlin 2.1.0 to avoid toolchain deprecation warnings.
- Lost debug connection on physical device
  - This can happen due to USB/power policies. The app normally remains running on the device even if the debug bridge disconnects.
- Index errors
  - The code avoids collectionGroup queries in write/delete paths; normal operations should not require custom indexes.

## Security

- For development, a temporary `authPassword` may be stored to enable full account deletion from the client. This is NOT recommended for production. See `SECURITY_NOTICE.md` for Admin SDK / Cloud Function alternatives.

## Tech stack

- Flutter, Firebase Auth, Cloud Firestore, mobile_scanner, qr_flutter, fl_chart, table_calendar, connectivity_plus, shared_preferences, intl

## Contributing

- Follow Dart style, document features, and keep the data model in sync with this README.

## License

- If you intend to publish, add a proper LICENSE file (MIT, Apache-2.0, etc.).

---

## Developer commands

Common commands you'll use during development:

```bash
# Install dependencies
flutter pub get

# Run on a specific device
flutter devices
flutter run -d <device-id>

# Clean and re-get packages
flutter clean
flutter pub get

# Build release artifacts
flutter build apk
flutter build appbundle

# Analyze code
flutter analyze

# Run tests (if/when present)
flutter test
```

## Detailed security notice (client-side deletion)

For development only, the app may store an `authPassword` field on user documents to enable complete deletion of Auth users from the client (because client apps cannot use the Admin SDK). Do NOT use this approach in production.

Recommended production approach (Cloud Functions with Admin SDK):

```js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.adminDeleteUser = functions.https.onCall(async (data, context) => {
  // TODO: enforce admin-only access (e.g., custom claims)
  const uid = data.uid;
  await admin.auth().deleteUser(uid);
  return { ok: true };
});
```

Also prefer disabling accounts or moving deletion to a secure backend that you control.

---
Built with ❤️ using Flutter and Firebase. Last updated: September 2025.
