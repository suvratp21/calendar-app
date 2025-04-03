import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async'; // Add this import for TimeoutException
import 'add_name_page.dart';
import 'add_event_page.dart';
import 'event_details_page.dart'; // Import the event details page

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
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

  Future<void> _signInWithGoogle() async {
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

  Future<void> _fetchCalendarEvents(DateTime date) async {
    if (_accessToken == null) return;

    // Calculate the range of dates to fetch (5 days before and after)
    DateTime startDate = date.subtract(const Duration(days: 5));
    DateTime endDate = date.add(const Duration(days: 5));

    // Check if the range is already cached
    if (_eventCache.containsKey(startDate) &&
        _eventCache.containsKey(endDate)) {
      print("Using cached events for range: $startDate to $endDate");
      for (int i = 0; i <= 10; i++) {
        DateTime currentDate = startDate.add(Duration(days: i));
        List<Appointment>? cachedEvents = _eventCache[currentDate];
        if (cachedEvents != null) {
          print("Cached events for $currentDate:");
          for (var event in cachedEvents) {
            print(
                "Event: ${event.subject}, Start: ${event.startTime}, End: ${event.endTime}");
          }
        }
      }
      setState(() {
        _calendarDataSource =
            AppointmentDataSource(_eventCache[_selectedDate] ?? []);
      });
      return;
    }

    final url = Uri.parse(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events?maxResults=250&orderBy=startTime&singleEvents=true&timeMin=${startDate.toUtc().toIso8601String()}&timeMax=${endDate.toUtc().toIso8601String()}');
    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $_accessToken'
      }).timeout(const Duration(seconds: 10)); // Add a timeout of 10 seconds

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
              // Convert event times to the local time zone
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
              print(
                  'Event: ${event['summary']}, Start: $startTime, End: $endTime');
            }
          } catch (e) {
            print('Error parsing event: $e');
          }
        }

        // Cache the events for the range
        setState(() {
          for (int i = 0; i <= 10; i++) {
            DateTime currentDate = startDate.add(Duration(days: i));
            _eventCache[currentDate] = appointments
                .where((event) =>
                    event.startTime.isAfter(currentDate) &&
                    event.startTime
                        .isBefore(currentDate.add(const Duration(days: 1))))
                .toList();
          }
          _calendarDataSource =
              AppointmentDataSource(_eventCache[_selectedDate] ?? []);
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

  List<Appointment> _getEventsForSelectedDate() {
    return _eventCache[_selectedDate] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
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
                child: Text('Add Name'),
              ),
              PopupMenuItem(
                value: 'refresh',
                child: Text('Refresh'),
              ),
              PopupMenuItem(
                value: 'add_event',
                child: Text('Add Event'),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Text('Logout'),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: user == null
            ? ElevatedButton(
                onPressed: _signInWithGoogle,
                child: const Text('Sign in with Google'),
              )
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    setState(() {
                      if (details.velocity.pixelsPerSecond.dx > 0) {
                        _selectedDate =
                            _selectedDate.subtract(const Duration(days: 1));
                      } else if (details.velocity.pixelsPerSecond.dx < 0) {
                        _selectedDate =
                            _selectedDate.add(const Duration(days: 1));
                      }
                      if (!_eventCache.containsKey(_selectedDate)) {
                        _fetchCalendarEvents(_selectedDate);
                      } else {
                        _calendarDataSource = AppointmentDataSource(
                            _eventCache[_selectedDate] ?? []);
                      }
                    });
                  },
                  child: Column(
                    children: [
                      Text(
                        ' ${_selectedDate.toLocal().toString().split(" ")[0]}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: SfCalendar(
                          view: CalendarView.day,
                          dataSource: _calendarDataSource,
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
                                    eventId:
                                        appointment.eventId, // Pass eventId
                                  ),
                                ),
                              );
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
  final DateTime startTime;
  final DateTime endTime;
  final String subject;
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
