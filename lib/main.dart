import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_calendar/calendar.dart';

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
  String? _accessToken;
  List<Appointment> _appointments = [];
  final CalendarController _calendarController = CalendarController();

  @override
  void initState() {
    super.initState();
    _calendarController.displayDate = DateTime.now();
  }

  Future<void> _signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn(
      scopes: ['email', 'https://www.googleapis.com/auth/calendar.readonly']
    ).signIn();
    if (googleUser == null) return;
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      setState(() {
        user = userCredential.user;
        _accessToken = googleAuth.accessToken;
      });
      print("Google sign in successful for user: ${user!.email}");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Google sign in successful")));
      await _fetchCalendarEvents();
    } catch (e) {
      print("Google sign in failed with error: ${e.toString()}");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Google sign in failed: ${e.toString()}")));
    }
  }

  Future<void> _fetchCalendarEvents() async {
    if (_accessToken == null) return;
    final url = Uri.parse('https://www.googleapis.com/calendar/v3/calendars/primary/events?maxResults=250&orderBy=startTime&singleEvents=true');
    final response = await http.get(url, headers: {'Authorization': 'Bearer $_accessToken'});
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final events = data['items'] as List<dynamic>;
      List<Appointment> appointments = [];
      for (var event in events) {
        String? startStr = event['start']['dateTime'] ?? event['start']['date'];
        String? endStr = event['end']?['dateTime'] ?? event['end']?['date'];
        if (startStr != null) {
          DateTime startTime = DateTime.parse(startStr);
          DateTime endTime;
          if (endStr != null) {
            endTime = DateTime.parse(endStr);
          } else {
            endTime = startTime.add(const Duration(hours: 1));
          }
          appointments.add(Appointment(
            startTime: startTime,
            endTime: endTime,
            subject: event['summary'] ?? 'No Title',
            color: Colors.blue,
          ));
        }
      }
      setState(() {
        _appointments = appointments;
      });
    } else {
      print('Failed to fetch calendar events: ${response.body}');
    }
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
              switch (value) {
                case 'refresh':
                  print('Refresh clicked');
                  break;
                case 'settings':
                  print('Settings clicked');
                  break;
                case 'add_event':
                  print('Add Event clicked');
                  break;
                case 'logout':
                  print('Logout clicked');
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Text('Refresh'),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Text('Settings'),
              ),
              const PopupMenuItem(
                value: 'add_event',
                child: Text('Add Event'),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Text('Logout'),
              ),
            ],
          )
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
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_left),
                        onPressed: () {
                          setState(() {
                            _calendarController.displayDate =
                                _calendarController.displayDate!
                                    .subtract(const Duration(days: 1));
                          });
                        },
                      ),
                      Text(
                        "${_calendarController.displayDate!.day}/${_calendarController.displayDate!.month}/${_calendarController.displayDate!.year}",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_right),
                        onPressed: () {
                          setState(() {
                            _calendarController.displayDate =
                                _calendarController.displayDate!
                                    .add(const Duration(days: 1));
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SfCalendar(
                      view: CalendarView.day,
                      controller: _calendarController,
                      dataSource: MeetingDataSource(_appointments),
                      appointmentBuilder:
                          (BuildContext context, CalendarAppointmentDetails details) {
                        final Appointment appointment = details.appointments.first;
                        return Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            appointment.subject,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                      timeSlotViewSettings: const TimeSlotViewSettings(
                        timeTextStyle: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<Appointment> source) {
    appointments = source;
  }
}
