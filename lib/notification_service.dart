import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

Future<void> sendEmail(String message, List<String> recipients) async {
  print('DEBUG: Preparing to send emails to recipients: $recipients');
  if (recipients.isEmpty) {
    print('DEBUG: No recipients to send email to.');
    return;
  }

  final googleSignIn = GoogleSignIn(scopes: [
    gmail.GmailApi.gmailSendScope,
    'email',
  ]);
  GoogleSignInAccount? googleUser = googleSignIn.currentUser;
  if (googleUser == null) {
    print('DEBUG: No Google user signed in. Prompting user to sign in.');
    try {
      googleUser = await googleSignIn.signIn();
      print('DEBUG: Google sign-in successful: ${googleUser?.email}');
    } catch (e) {
      print('DEBUG: Google sign-in failed: $e');
      return;
    }
    if (googleUser == null) {
      print('DEBUG: User cancelled Google sign-in.');
      return;
    }
  } else {
    print('DEBUG: Google user already signed in: ${googleUser.email}');
  }

  final googleAuth = await googleUser.authentication;
  print('DEBUG: Access token: ${googleAuth.accessToken}');
  if (googleAuth.accessToken == null) {
    print('DEBUG: Google access token is null.');
    return;
  }

  final authClient = authenticatedClient(
    Client(),
    AccessCredentials(
      AccessToken('Bearer', googleAuth.accessToken!,
          DateTime.now().add(const Duration(hours: 1))),
      null,
      [gmail.GmailApi.gmailSendScope, 'email'],
    ),
  );

  final gmailApi = gmail.GmailApi(authClient);

  for (String recipient in recipients) {
    final subject = 'Event Notification';
    final rawMessage = 'To: $recipient\r\n'
        'Subject: $subject\r\n'
        'Content-Type: text/plain; charset="UTF-8"\r\n'
        '\r\n'
        '$message';

    final base64Message = base64UrlEncode(utf8.encode(rawMessage));
    final gmail.Message gmailMessage = gmail.Message()..raw = base64Message;

    try {
      print('DEBUG: Sending email to $recipient...');
      final response = await gmailApi.users.messages.send(gmailMessage, 'me');
      print('DEBUG: Gmail API response: ${response.toJson()}');
      print('DEBUG: Email sent successfully to $recipient via Gmail API.');
    } catch (e, stack) {
      print('DEBUG: Error sending email to $recipient via Gmail API: $e');
      print('DEBUG: Stack trace: $stack');
    }
  }
  print('DEBUG: Finished sending emails to all recipients.');
}

Future<int> getNotificationMinutes() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('notificationMinutes') ?? 10;
}

Future<void> scheduleNotification(Appointment appointment) async {
  final notificationMinutes = await getNotificationMinutes();
  final notificationTime =
      appointment.startTime.subtract(Duration(minutes: notificationMinutes));
  if (notificationTime.isAfter(DateTime.now())) {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: appointment.eventId.hashCode,
          channelKey: 'basic_channel',
          title: 'Upcoming Event',
          body:
              'Your event "${appointment.subject}" starts in $notificationMinutes minutes.',
          notificationLayout: NotificationLayout.Default,
          payload: {
            'eventId': appointment.eventId,
            'eventName': appointment.subject,
            'attendees': appointment.attendees?.join(','),
          },
          color: appointment.color,
        ),
        actionButtons: [
          NotificationActionButton(key: 'ON_TIME', label: 'On Time'),
          NotificationActionButton(key: 'RUNNING_LATE', label: 'Running Late'),
          NotificationActionButton(key: 'POSTPONE', label: 'Postpone'),
        ],
        schedule: NotificationCalendar.fromDate(date: notificationTime),
      );
      print(
          'Notification scheduled for event: ${appointment.subject} to ${appointment.attendees.toString()} at $notificationTime');
    } catch (e) {
      print(
          'Failed to schedule notification for event: ${appointment.subject}. Error: $e');
    }
  } else {
    print(
        'Notification not scheduled for event: ${appointment.subject} as the time has already passed.');
  }
}

Future<String> getEventActionMessage(String eventTitle, String action) async {
  final prefs = await SharedPreferences.getInstance();
  String template;
  switch (action) {
    case 'RUNNING_LATE':
      template = prefs.getString('defaultRunningLate') ??
          'Regarding "{event}": I will be late.';
      break;
    case 'POSTPONE':
      template = prefs.getString('defaultPostpone') ??
          'Regarding "{event}": The event is postponed.';
      break;
    default:
      template = '';
  }
  return template.replaceAll('{event}', eventTitle);
}

@pragma('vm:entry-point')
Future<void> onNotificationAction(ReceivedAction receivedAction) async {
  String? eventId = receivedAction.payload?['eventId'];
  String? attendeesPayload = receivedAction.payload?['attendees'];
  List<String> members = [];
  List<String> attendeesList =
      attendeesPayload != null && attendeesPayload.isNotEmpty
          ? attendeesPayload.split(',')
          : [];
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
      if (eventData != null) {
        if (eventData.containsKey('members')) {
          members = List<String>.from(eventData['members']);
          print('Fetched members for event $eventId: $members');
        } else {
          print('No members found for event $eventId.');
        }
      }
    } else {
      print('Event with ID $eventId does not exist.');
    }
  } catch (e) {
    print('Error fetching event details: $e');
    return;
  }
  final eventTitle = receivedAction.title ?? '';
  switch (receivedAction.buttonKeyPressed) {
    case 'ON_TIME':
      print('User selected "On Time" for event: $eventTitle');
      break;
    case 'RUNNING_LATE':
      print('User selected "Running Late" for event: $eventTitle');
      final msg = await getEventActionMessage(eventTitle, 'RUNNING_LATE');
      await sendSms(msg, members);
      await sendEmail(msg, attendeesList);
      break;
    case 'POSTPONE':
      print('User selected "Postpone" for event: $eventTitle');
      final msg = await getEventActionMessage(eventTitle, 'POSTPONE');
      await sendSms(msg, members);
      await sendEmail(msg, attendeesList);
      break;
    default:
      print(
          'Unhandled notification action: ${receivedAction.buttonKeyPressed}');
  }
}

class NotificationService {
  static int _defaultNotificationTime = 10;

  static void updateDefaultNotificationTime(int minutes) {
    _defaultNotificationTime = minutes;
  }

  static Future<void> scheduleEventNotification(
      String title, DateTime eventTime) async {
    final notificationTime = eventTime.subtract(
      Duration(minutes: _defaultNotificationTime),
    );
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
