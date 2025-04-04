import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'add_name_page.dart';
import 'add_event_page.dart';
import 'event_details_page.dart';
import 'models.dart' as myModels;
import 'calendar_service.dart';
import 'notification_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  User? user;
  final TextEditingController _nameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _accessToken;
  myModels.AppointmentDataSource? _calendarDataSource;
  bool _isUpdatingCalendar = false; // added flag

  @override
  void initState() {
    super.initState();
    _attemptSilentSignIn();
    _requestNotificationPermissions();
  }

  Future<void> _requestNotificationPermissions() async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
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
        _fetchEvents();
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    PermissionStatus contactStatus;
    do {
      contactStatus = await Permission.contacts.request();
    } while (contactStatus.isDenied);

    if (!contactStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact permission not granted.')));
      return;
    }

    final GoogleSignInAccount? googleUser = await GoogleSignIn(scopes: [
      'email',
      'https://www.googleapis.com/auth/calendar.readonly'
    ]).signIn();
    if (googleUser == null) return;
    final googleAuth = await googleUser.authentication;
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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google sign in successful")));
      _fetchEvents();
    } catch (e) {
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

  void _fetchEvents() {
    if (_accessToken != null) {
      fetchCalendarEvents(_accessToken!, _selectedDate).then((appointments) {
        setState(() {
          _calendarDataSource = myModels.AppointmentDataSource(appointments);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: (value) {
              if (value == 'add_name') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddNamePage(
                        user: user, initialName: _nameController.text),
                  ),
                ).then((result) {
                  if (result != null) {
                    setState(() {
                      _nameController.text = result;
                    });
                  }
                });
              } else if (value == 'refresh') {
                _fetchEvents();
              } else if (value == 'add_event') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddEventPage()),
                );
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                  value: 'add_name',
                  child:
                      Text('Add Name', style: TextStyle(color: Colors.black))),
              PopupMenuItem(
                  value: 'refresh',
                  child:
                      Text('Refresh', style: TextStyle(color: Colors.black))),
              PopupMenuItem(
                  value: 'add_event',
                  child:
                      Text('Add Event', style: TextStyle(color: Colors.black))),
              PopupMenuItem(
                  value: 'logout',
                  child: Text('Logout', style: TextStyle(color: Colors.black))),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(color: Colors.white),
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
                        borderRadius: BorderRadius.circular(20.0)),
                  ),
                  child: const Text('Sign in with Google'),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SfCalendar(
                        initialDisplayDate: _selectedDate, // new line added
                        view: CalendarView.day,
                        dataSource: _calendarDataSource,
                        headerStyle: const CalendarHeaderStyle(
                          textAlign: TextAlign.center,
                          backgroundColor: Colors.white,
                          textStyle: TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                        todayHighlightColor: Colors.black,
                        onViewChanged: (ViewChangedDetails details) {
                          if (details.visibleDates.isNotEmpty) {
                            DateTime newSelectedDate =
                                details.visibleDates.first;
                            if (newSelectedDate != _selectedDate) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                setState(() {
                                  _selectedDate = newSelectedDate;
                                });
                                _fetchEvents();
                              });
                            }
                          }
                        },
                        onTap: (CalendarTapDetails details) {
                          if (details.appointments != null &&
                              details.appointments!.isNotEmpty) {
                            final myModels.Appointment appointment =
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
                                      updatedAppointment['subject'];
                                  appointment.startTime =
                                      updatedAppointment['startTime'];
                                  appointment.endTime =
                                      updatedAppointment['endTime'];
                                });
                                updateGoogleCalendarEvent(
                                    _accessToken!, appointment);
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
    );
  }
}
