import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
  List<Appointment> _appointments = [];
  String? _accessToken;

  Future<void> _signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
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

  Future<void> _fetchCalendarEvents() async {
    if (_accessToken == null) return;
    final url = Uri.parse(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events?maxResults=250&orderBy=startTime&singleEvents=true');
    final response =
        await http.get(url, headers: {'Authorization': 'Bearer $_accessToken'});
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
            DateTime startTime = DateTime.parse(startStr);
            DateTime endTime = endStr != null
                ? DateTime.parse(endStr)
                : startTime.add(const Duration(hours: 1));
            appointments.add(Appointment(
              startTime: startTime,
              endTime: endTime,
              subject: event['summary'] ?? 'No Title',
              color: Colors.blue,
            ));
            print(
                'Event: ${event['summary']}, Start: $startTime, End: $endTime');
          }
        } catch (e) {
          print('Error parsing event: $e');
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
                _fetchCalendarEvents();
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
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Expanded(
                      child: SfCalendar(
                        view: CalendarView.day,
                        dataSource: AppointmentDataSource(_appointments),
                      ),
                    ),
                  ],
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
  });
  final DateTime startTime;
  final DateTime endTime;
  final String subject;
  final Color color;
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

class AddNamePage extends StatefulWidget {
  final User? user;
  final String initialName;
  const AddNamePage({super.key, required this.user, required this.initialName});

  @override
  State<AddNamePage> createState() => _AddNamePageState();
}

class _AddNamePageState extends State<AddNamePage> {
  late TextEditingController _pageNameController;

  @override
  void initState() {
    super.initState();
    _pageNameController = TextEditingController(text: widget.initialName);
    if (widget.user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please sign in first")));
        Navigator.of(context).pop();
      });
    }
  }

  Future<void> _saveName() async {
    if (_pageNameController.text.isEmpty || widget.user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user!.uid)
        .set({'name': _pageNameController.text});
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Name successfully saved")));
    Navigator.of(context).pop(_pageNameController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Name")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _pageNameController,
              decoration: const InputDecoration(labelText: "Enter your name"),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveName,
                    child: const Text("Save"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Cancel"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AddEventPage extends StatefulWidget {
  const AddEventPage({super.key});

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  final TextEditingController _eventController = TextEditingController();

  Future<void> _saveEvent() async {
    if (_eventController.text.isEmpty) return;
    // TODO: Implement saving event to your data source
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Event successfully saved")),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Event")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _eventController,
              decoration: const InputDecoration(labelText: "Event Title"),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveEvent,
                    child: const Text("Save"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Cancel"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
