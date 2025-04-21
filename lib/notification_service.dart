import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';
import 'package:flutter/foundation.dart';

Future<void> sendSms(String message, List<String> members) async {
  print('DEBUG: Preparing to send message to members: $members');
  if (members.isEmpty) {
    print('DEBUG: No members to send message to.');
    return;
  }
  for (String member in members) {
    final String encodedMessage = Uri.encodeComponent(message);
    final Uri whatsappUri =
        Uri.parse('whatsapp://send?phone=$member&text=$encodedMessage');
    final Uri smsUri = Uri.parse('sms:$member?body=$encodedMessage');
    try {
      print('DEBUG: Checking if WhatsApp is available for $member.');
      final bool isWhatsappAvailable = await canLaunchUrl(whatsappUri);
      print(isWhatsappAvailable);
      if (isWhatsappAvailable) {
        print(
            'DEBUG: Sending WhatsApp message to $member with URI: $whatsappUri');
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        print('DEBUG: WhatsApp message sent successfully to $member.');
      } else {
        print(
            'DEBUG: WhatsApp not available for $member. Launching SMS directly.');
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri, mode: LaunchMode.externalApplication);
          print('DEBUG: SMS sent successfully to $member.');
        } else {
          print('DEBUG: Could not send SMS to $member. URI: $smsUri');
        }
      }
    } catch (e) {
      print('DEBUG: Error while sending message to $member: $e');
    }
  }
  print('DEBUG: Finished sending messages to all members.');
}

Future<void> scheduleNotification(Appointment appointment) async {
  final notificationTime =
      appointment.startTime.subtract(const Duration(minutes: 10));
  if (notificationTime.isAfter(DateTime.now())) {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: appointment.eventId.hashCode,
          channelKey: 'basic_channel',
          title: 'Upcoming Event',
          body: 'Your event "${appointment.subject}" starts in 10 minutes.',
          notificationLayout: NotificationLayout.Default,
          payload: {'eventId': appointment.eventId},
        ),
        actionButtons: [
          NotificationActionButton(key: 'ON_TIME', label: 'On Time'),
          NotificationActionButton(key: 'RUNNING_LATE', label: 'Running Late'),
          NotificationActionButton(key: 'POSTPONE', label: 'Postpone'),
        ],
        schedule: NotificationCalendar.fromDate(date: notificationTime),
      );
      print(
          'Notification scheduled for event: ${appointment.subject} at $notificationTime');
    } catch (e) {
      print(
          'Failed to schedule notification for event: ${appointment.subject}. Error: $e');
    }
  } else {
    print(
        'Notification not scheduled for event: ${appointment.subject} as the time has already passed.');
  }
}

@pragma('vm:entry-point')
Future<void> onNotificationAction(ReceivedAction receivedAction) async {
  String? eventId = receivedAction.payload?['eventId'];
  if (eventId == null) {
    print('No event ID found in notification payload.');
    return;
  }
  List<String> members = [];
  try {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail == null) {
      print('User email not found.');
      return;
    }
    DocumentSnapshot eventSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userEmail)
        .collection('events')
        .doc(eventId)
        .get();
    if (eventSnapshot.exists) {
      Map<String, dynamic>? eventData =
          eventSnapshot.data() as Map<String, dynamic>?;
      if (eventData != null && eventData.containsKey('members')) {
        members = List<String>.from(eventData['members']);
        print('Fetched members for event $eventId: $members');
      } else {
        print('No members found for event $eventId.');
      }
    } else {
      print('Event with ID $eventId does not exist.');
    }
  } catch (e) {
    print('Error fetching event details: $e');
    return;
  }
  switch (receivedAction.buttonKeyPressed) {
    case 'ON_TIME':
      print('User selected "On Time" for event: ${receivedAction.title}');
      break;
    case 'RUNNING_LATE':
      print('User selected "Running Late" for event: ${receivedAction.title}');
      await sendSms(
          'Regarding "${receivedAction.title}": I will be late.', members);
      break;
    case 'POSTPONE':
      print('User selected "Postpone" for event: ${receivedAction.title}');
      await sendSms(
          'Regarding "${receivedAction.title}": The event is postponed.',
          members);
      break;
    default:
      print(
          'Unhandled notification action: ${receivedAction.buttonKeyPressed}');
  }
}

class NotificationService {
  static int _defaultNotificationTime = 10; // Default to 10 minutes

  static void updateDefaultNotificationTime(int minutes) {
    _defaultNotificationTime = minutes;
  }

  static Future<void> scheduleEventNotification(
      String title, DateTime eventTime) async {
    final notificationTime = eventTime.subtract(
      Duration(minutes: _defaultNotificationTime),
    );
    // Schedule the notification
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: UniqueKey().hashCode,
        channelKey: 'basic_channel',
        title: title,
        body: 'Your event is coming up!',
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar.fromDate(date: notificationTime),
    );
  }
}
