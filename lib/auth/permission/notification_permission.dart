import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

// Utility class to handle notification permission requests
class NotificationPermission {
  // Requests notification permission from the user if not already granted
  static Future<void> request(BuildContext context) async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      // Show a dialog prompting the user to allow notifications
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Allow Notifications'),
          content: const Text(
              'This app needs permission to send you notifications.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Deny'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await AwesomeNotifications()
                    .requestPermissionToSendNotifications();
              },
              child: const Text('Allow'),
            ),
          ],
        ),
      );
    }
  }
}
