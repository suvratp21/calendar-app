import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'homepage.dart';
import 'notification_service.dart';

// Entry point of the application
final GoogleSignIn googleSignIn = GoogleSignIn(
  scopes: [
    'email',
    'https://www.googleapis.com/auth/calendar.readonly',
    'https://www.googleapis.com/auth/calendar',
  ],
);

void main() async {
  // Ensure Flutter bindings are initialized before using platform channels
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase for the app
  await Firebase.initializeApp();

  // Initialize Awesome Notifications with a basic channel
  AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'basic_channel',
        channelName: 'Basic Notifications',
        channelDescription: 'Notification channel for basic tests',
        defaultColor: Colors.deepPurple,
        ledColor: Colors.white,
        importance: NotificationImportance.High,
        channelShowBadge: true,
      )
    ],
  );

  // Request notification permission if not already granted
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  // Set up notification action listeners
  AwesomeNotifications().setListeners(
    onActionReceivedMethod: onNotificationAction,
  );

  // Start the Flutter app
  runApp(const MyApp());
}

// Root widget of the app
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Calendar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthScreen(),
    );
  }
}
