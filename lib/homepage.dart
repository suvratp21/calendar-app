import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'add_event_page.dart';
import 'event_details_page.dart';
import 'settings_page.dart';
import 'models.dart' as myModels;
import 'calendar_service.dart';
import 'notification_service.dart';
import 'auth/auth_service.dart';
import 'auth/permission/notification_permission.dart' as localNotificationPermission;
import 'auth/permission/contact_permission.dart';

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
  final bool _isUpdatingCalendar = false;
  final CalendarController _calendarController = CalendarController();
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService(GoogleSignIn(
      scopes: ['email', 'https://www.googleapis.com/auth/calendar.readonly'],
    ));
    _attemptSilentSignIn();
    localNotificationPermission.NotificationPermission.request(context);
  }

  Future<void> _attemptSilentSignIn() async {
    final currentUser = _authService.currentUser;
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
    bool contactGranted = await ContactPermission.request();
    if (!contactGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact permission not granted.')));
      return;
    }
    final signedInUser = await _authService.signInWithGoogle();
    if (signedInUser == null) return;
    final googleUser = await GoogleSignIn(scopes: [
      'email',
      'https://www.googleapis.com/auth/calendar.readonly'
    ]).signInSilently();
    final googleAuth = await googleUser?.authentication;
    setState(() {
      user = signedInUser;
      _accessToken = googleAuth?.accessToken;
    });
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Google sign in successful")));
    _fetchEvents();
  }

  Future<void> _logout() async {
    await _authService.signOut();
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
        title: const Text('Smart Calendar'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: (value) {
              if (value == 'refresh') {
                _fetchEvents();
              } else if (value == 'add_event') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddEventPage()),
                );
              } else if (value == 'go_to') {
                showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                ).then((selectedDate) {
                  if (selectedDate != null) {
                    setState(() {
                      _selectedDate = selectedDate;
                    });
                    _calendarController.displayDate = selectedDate;
                    _fetchEvents();
                  }
                });
              } else if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                  value: 'refresh',
                  child:
                      Text('Refresh', style: TextStyle(color: Colors.black))),
              PopupMenuItem(
                  value: 'add_event',
                  child:
                      Text('Add Event', style: TextStyle(color: Colors.black))),
              PopupMenuItem(
                  value: 'go_to',
                  child: Text('Go to', style: TextStyle(color: Colors.black))),
              PopupMenuItem(
                  value: 'settings',
                  child:
                      Text('Settings', style: TextStyle(color: Colors.black))),
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
                        controller: _calendarController,
                        initialDisplayDate: _selectedDate,
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
                                  attendees: appointment.attendees,
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "addEventFab",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddEventPage()),
              );
            },
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "notifyFab",
            onPressed: () {
              AwesomeNotifications().createNotification(
                content: NotificationContent(
                  id: 1,
                  channelKey: 'basic_channel',
                  title: 'Hello!',
                  body: 'Hello World!',
                ),
              );
            },
            child: const Icon(Icons.notifications),
          ),
        ],
      ),
    );
  }
}
