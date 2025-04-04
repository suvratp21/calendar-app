import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async'; // Add this import for TimeoutException
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:url_launcher/url_launcher.dart'; // Add this import for launching messaging apps
import 'add_name_page.dart';
import 'add_event_page.dart';
import 'event_details_page.dart'; // Import the event details page

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize Awesome Notifications
  AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'basic_channel',
        channelName: 'Basic Notifications',
        channelDescription: 'Notification channel for basic tests',
        defaultColor: Colors.deepPurple,
        ledColor: Colors.white,
      )
    ],
  );

  // Register the global notification action handler
  AwesomeNotifications().setListeners(
    onActionReceivedMethod: onNotificationAction,
  );

  runApp(const MyApp());
}

// Global static method to handle notification actions
@pragma('vm:entry-point') // Required for background execution
Future<void> onNotificationAction(ReceivedAction receivedAction) async {
  switch (receivedAction.buttonKeyPressed) {
    case 'ON_TIME':
      print('User selected "On Time" for event: ${receivedAction.title}');
      break;
    case 'RUNNING_LATE':
      print('User selected "Running Late" for event: ${receivedAction.title}');
      await _sendSms('Regarding "${receivedAction.title}": I will be late.');
      break;
    case 'POSTPONE':
      print('User selected "Postpone" for event: ${receivedAction.title}');
      await _sendSms(
          'Regarding "${receivedAction.title}": The event is postponed.');
      break;
    default:
      print(
          'Unhandled notification action: ${receivedAction.buttonKeyPressed}');
  }
}

// Helper method to send SMS
Future<void> _sendSms(String message) async {
  final String encodedMessage = Uri.encodeComponent(message);
  final Uri smsUri = Uri.parse('sms:?body=$encodedMessage');

  try {
    print('Attempting to send SMS: $smsUri');
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      print('SMS sent successfully.');
    } else {
      print('Could not send SMS. URI: $smsUri');
    }
  } catch (e) {
    print('Error while sending SMS: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  User? user;
  final TextEditingController _nameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  // Correctly initialize _eventCache as an empty map
  final Map<DateTime, List<Appointment>> _eventCache = {};

  String? _accessToken;
  AppointmentDataSource? _calendarDataSource;

  @override
  void initState() {
    super.initState();
    _attemptSilentSignIn(); // Added to restore credentials silently
    _requestNotificationPermissions(); // Request notification permissions
  }

  Future<void> _sendMessageToEventMembers(
      String eventName, String message) async {
    final String encodedMessage =
        Uri.encodeComponent('Regarding "$eventName": $message');
    final Uri smsUri = Uri.parse('sms:?body=$encodedMessage');

    try {
      print('Attempting to launch SMS URI: $smsUri');
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        print('Successfully launched messaging app.');
      } else {
        print('Could not launch messaging app. URI: $smsUri');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open messaging app.')),
        );
      }
    } on PlatformException catch (e) {
      print('PlatformException while launching messaging app: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('An error occurred while sending the message.')),
      );
    } catch (e) {
      print('Unexpected error while launching messaging app: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'An unexpected error occurred while sending the message.')),
      );
    }
  }

  Future<void> _requestNotificationPermissions() async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      // Show a dialog to request permissions
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Allow Notifications'),
          content: const Text(
              'This app needs permission to send you notifications.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
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

  Future<void> _attemptSilentSignIn() async {
    // New method to restore credentials
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final googleUser = await GoogleSignIn(scopes: [
        'email',
        'https://www.googleapis.com/auth/calendar.readonly'
      ]).signInSilently();
      if (googleUser != null) {
        final googleAuth = await googleUser.authentication;
        setState(() {
          user = currentUser;
          _accessToken = googleAuth.accessToken;
        });
        await _fetchCalendarEvents(_selectedDate);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    // Always ask for contact permission until it's either granted or permanently denied
    PermissionStatus contactStatus;
    do {
      contactStatus = await Permission.contacts.request();
      // Loop only if permission is temporarily denied.
    } while (contactStatus.isDenied);

    if (!contactStatus.isGranted) {
      // covers permanently denied scenario
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact permission not granted.')));
      return;
    }

    final GoogleSignInAccount? googleUser = await GoogleSignIn(scopes: [
      'email',
      'https://www.googleapis.com/auth/calendar.readonly'
    ]).signIn();
    if (googleUser == null) return;
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      setState(() {
        user = userCredential.user;
        _accessToken = googleAuth.accessToken;
      });
      print("Google sign in successful for user: ${user!.email}");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google sign in successful")));
      await _fetchCalendarEvents(_selectedDate); // Pass _selectedDate here
    } catch (e) {
      print("Google sign in failed with error: ${e.toString()}");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Google sign in failed: ${e.toString()}")));
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    setState(() {
      user = null;
      _accessToken = null;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Logged out successfully")));
  }

  Future<void> _submitName() async {
    if (_nameController.text.isEmpty || user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      'name': _nameController.text,
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Name successfully saved")));
  }

  // Helper to normalize a DateTime to its date only.
  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Future<void> _scheduleNotification(Appointment appointment) async {
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
          ),
          actionButtons: [
            NotificationActionButton(
              key: 'ON_TIME',
              label: 'On Time',
            ),
            NotificationActionButton(
              key: 'RUNNING_LATE',
              label: 'Running Late',
            ),
            NotificationActionButton(
              key: 'POSTPONE',
              label: 'Postpone',
            ),
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

  Future<void> _fetchCalendarEvents(DateTime date) async {
    if (_accessToken == null) return;

    // Calculate the range of dates to fetch (5 days before and after)
    DateTime startDate = _normalizeDate(date.subtract(const Duration(days: 5)));
    DateTime endDate = _normalizeDate(date.add(const Duration(days: 5)));

    // Check if the range is already cached using normalized keys
    if (_eventCache.containsKey(_normalizeDate(date))) {
      print("Using cached events for date: ${_normalizeDate(date)}");
      setState(() {
        _calendarDataSource =
            AppointmentDataSource(_eventCache[_normalizeDate(date)] ?? []);
      });
      return;
    }

    final url = Uri.parse(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events?maxResults=250&orderBy=startTime&singleEvents=true&timeMin=${startDate.toUtc().toIso8601String()}&timeMax=${endDate.toUtc().toIso8601String()}');
    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $_accessToken'
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final events = data['items'] as List<dynamic>;
        List<Appointment> appointments = [];
        for (var event in events) {
          try {
            String? startStr =
                event['start']['dateTime'] ?? event['start']['date'];
            String? endStr = event['end']?['dateTime'] ?? event['end']?['date'];
            if (startStr != null) {
              DateTime startTime = DateTime.parse(startStr).toLocal();
              DateTime endTime = endStr != null
                  ? DateTime.parse(endStr).toLocal()
                  : startTime.add(const Duration(hours: 1));
              appointments.add(Appointment(
                startTime: startTime,
                endTime: endTime,
                subject: event['summary'] ?? 'No Title',
                color: Colors.blue,
                eventId: event['id'] ?? '',
              ));
              // Schedule notification for the event
              _scheduleNotification(appointments.last);
              print(
                  'Event: ${event['summary']}, Start: $startTime, End: $endTime');
            }
          } catch (e) {
            print('Error parsing event: $e');
          }
        }

        // Cache the events for each day in the range using normalized dates
        setState(() {
          for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
            DateTime currentDate =
                _normalizeDate(startDate.add(Duration(days: i)));
            DateTime dayStart = currentDate;
            DateTime dayEnd = currentDate.add(const Duration(days: 1));
            _eventCache[currentDate] = appointments
                .where((event) =>
                    event.startTime.isBefore(dayEnd) &&
                    event.endTime.isAfter(dayStart))
                .toList();
          }
          _calendarDataSource =
              AppointmentDataSource(_eventCache[_normalizeDate(date)] ?? []);
        });
      } else {
        print('Failed to fetch calendar events: ${response.body}');
      }
    } on TimeoutException catch (_) {
      print('Request to fetch calendar events timed out.');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Request timed out. Please try again.")));
    } catch (e) {
      print('Error fetching calendar events: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error fetching events: $e")));
    }
  }

  Future<void> _updateGoogleCalendarEvent(
      Appointment updatedAppointment) async {
    if (_accessToken == null || updatedAppointment.eventId.isEmpty) return;
    final url = Uri.parse(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events/${updatedAppointment.eventId}');
    final body = json.encode({
      'summary': updatedAppointment.subject,
      'start': {
        'dateTime': updatedAppointment.startTime.toUtc().toIso8601String()
      },
      'end': {'dateTime': updatedAppointment.endTime.toUtc().toIso8601String()},
    });
    try {
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: body,
      );
      if (response.statusCode == 200) {
        print('Google event updated successfully.');
        print('DEBUG: Updated event data: $body');
      } else {
        print('Failed to update Google event: ${response.body}');
        print('DEBUG: Response status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating Google event: $e');
    }
  }

  List<Appointment> _getEventsForSelectedDate() {
    return _eventCache[_normalizeDate(_selectedDate)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black, // Ensure text/icons are visible
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: (value) {
              if (value == 'add_name') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddNamePage(
                      user: user,
                      initialName: _nameController.text,
                    ),
                  ),
                ).then((result) {
                  if (result != null) {
                    setState(() {
                      _nameController.text = result;
                    });
                  }
                });
              } else if (value == 'refresh') {
                _fetchCalendarEvents(_selectedDate);
              } else if (value == 'add_event') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddEventPage(),
                  ),
                );
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'add_name',
                child: Text('Add Name', style: TextStyle(color: Colors.black)),
              ),
              PopupMenuItem(
                value: 'refresh',
                child: Text('Refresh', style: TextStyle(color: Colors.black)),
              ),
              PopupMenuItem(
                value: 'add_event',
                child: Text('Add Event', style: TextStyle(color: Colors.black)),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Text('Logout', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Center(
          child: user == null
              ? ElevatedButton(
                  onPressed: _signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 12.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                  ),
                  child: const Text('Sign in with Google'),
                )
              : GestureDetector(
                  onHorizontalDragEnd: (details) {
                    setState(() {
                      if (details.velocity.pixelsPerSecond.dx > 0) {
                        _selectedDate =
                            _selectedDate.subtract(const Duration(days: 1));
                      } else if (details.velocity.pixelsPerSecond.dx < 0) {
                        _selectedDate =
                            _selectedDate.add(const Duration(days: 1));
                      }
                      if (!_eventCache
                          .containsKey(_normalizeDate(_selectedDate))) {
                        _fetchCalendarEvents(_selectedDate);
                      } else {
                        _calendarDataSource = AppointmentDataSource(
                            _eventCache[_normalizeDate(_selectedDate)] ?? []);
                      }
                    });
                  },
                  child: Column(
                    children: [
                      Text(
                        ' ${_selectedDate.toLocal().toString().split(" ")[0]}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: SfCalendar(
                          view: CalendarView.day,
                          dataSource: _calendarDataSource,
                          headerStyle: const CalendarHeaderStyle(
                            textAlign: TextAlign.center,
                            backgroundColor: Colors.white,
                            textStyle: TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          todayHighlightColor: Colors.black,
                          onTap: (CalendarTapDetails details) {
                            if (details.appointments != null &&
                                details.appointments!.isNotEmpty) {
                              final Appointment appointment =
                                  details.appointments!.first;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EventDetailsPage(
                                    appointment: appointment,
                                    eventId: appointment.eventId,
                                  ),
                                ),
                              ).then((updatedAppointment) {
                                if (updatedAppointment != null) {
                                  setState(() {
                                    appointment.subject =
                                        updatedAppointment.subject;
                                    appointment.startTime =
                                        updatedAppointment.startTime;
                                    appointment.endTime =
                                        updatedAppointment.endTime;
                                  });
                                  _updateGoogleCalendarEvent(appointment);
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class Meeting {
  Meeting(this.eventName, this.from, this.to, this.background, this.isAllDay);
  final String eventName;
  final DateTime from;
  final DateTime to;
  final Color background;
  final bool isAllDay;
}

class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<Meeting> source) {
    appointments = source;
  }
  @override
  DateTime getStartTime(int index) => appointments![index].from;
  @override
  DateTime getEndTime(int index) => appointments![index].to;
  @override
  String getSubject(int index) => appointments![index].eventName;
  @override
  Color getColor(int index) => appointments![index].background;
  @override
  bool isAllDay(int index) => appointments![index].isAllDay;
}

class Appointment {
  Appointment({
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.color,
    required this.eventId,
  });

  DateTime startTime; // Removed 'final' to make it mutable
  DateTime endTime; // Removed 'final' to make it mutable
  String subject; // Removed 'final' to make it mutable
  final Color color;
  final String eventId;
}

class AppointmentDataSource extends CalendarDataSource {
  AppointmentDataSource(List<Appointment> source) {
    appointments = source;
  }
  @override
  DateTime getStartTime(int index) => appointments![index].startTime;
  @override
  DateTime getEndTime(int index) => appointments![index].endTime;
  @override
  String getSubject(int index) => appointments![index].subject;
  @override
  Color getColor(int index) => appointments![index].color;
}
