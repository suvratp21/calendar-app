# Calendar App

A Flutter-based calendar and event management app with notification and messaging features.

## Features

- Schedule and manage events with reminders.
- Receive local notifications before events.
- Notify event members via WhatsApp and SMS.
- Google Sign-In and Gmail API integration for sending emails.
- Customizable notification lead time.
- Firebase integration for user and event data.

## Getting Started

### Prerequisites

- [Flutter](https://flutter.dev/docs/get-started/install)
- Firebase project (for authentication and Firestore)
- Google Cloud project with Gmail API enabled

### Setup

1. **Clone the repository:**
   ```
   git clone <repo-url>
   cd calendar-app
   ```

2. **Install dependencies:**
   ```
   flutter pub get
   ```

3. **Configure Google Cloud:**
   - Visit [Google Cloud Console](https://console.cloud.google.com/).
   - Create a new project and open it.
   - Go to `APIs & Services` -> `OAuth consent screen` and configure it.
   - Go to `APIs & Services` -> `Credentials` and create OAuth 2.0 credentials.
   - Enable the Gmail API for your project.
   - Download your OAuth client ID and add it to your app as required.

4. **Configure Firebase:**
   - Visit [Firebase Console](https://console.firebase.google.com/).
   - Create a project and link it to your Google Cloud project.
   - Create a Firestore database. For testing, you can use the following rules:
     ```
     rules_version = '2';
     service cloud.firestore {
       match /databases/{database}/documents {
         match /{document=**} {
           allow read, write: if true;
         }
       }
     }
     ```
   - Go to Authentication and enable Google sign-in.
   - Go to Project settings, add your app's SHA-1 key, and download `google-services.json` (Android).
   - Place `google-services.json` in `android/app/`.

5. **Run the app:**
   ```
   flutter run
   ```

## Usage

- Add events and invite members.
- Set your preferred notification lead time in settings.
- When a notification appears, respond with "On Time", "Running Late", or "Postpone".
- The app will notify members via WhatsApp and SMS based on your response.

## Dependencies

- [awesome_notifications](https://pub.dev/packages/awesome_notifications)
- [firebase_auth](https://pub.dev/packages/firebase_auth)
- [cloud_firestore](https://pub.dev/packages/cloud_firestore)
- [googleapis](https://pub.dev/packages/googleapis)
- [google_sign_in](https://pub.dev/packages/google_sign_in)
- [shared_preferences](https://pub.dev/packages/shared_preferences)
- [url_launcher](https://pub.dev/packages/url_launcher)

## Notes
- For production, update Firestore security rules to restrict access.
- Ensure all required API keys and credentials are kept secure.

