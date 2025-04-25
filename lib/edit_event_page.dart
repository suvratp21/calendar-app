import 'package:flutter/material.dart';
// Import models with alias to avoid naming conflicts
import 'models.dart' as myModels;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth/permission/contact_permission.dart';

// Google Sign-In instance with required scopes
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: [
    'email',
    'https://www.googleapis.com/auth/calendar.readonly',
    'https://www.googleapis.com/auth/calendar',
  ],
);

// EditEventPage allows editing and deleting an existing event
class EditEventPage extends StatefulWidget {
  final myModels.Appointment appointment; // Appointment to edit
  final String eventId; // Unique event ID
  final List<String> members; // List of event members

  const EditEventPage({
    super.key,
    required this.appointment,
    required this.eventId,
    required this.members,
  });

  @override
  State<EditEventPage> createState() => _EditEventPageState();
}

class _EditEventPageState extends State<EditEventPage> {
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _descriptionController;
  late List<String> _members;
  DateTime? _startTime;
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    // Initialize controllers and state from the provided appointment
    _titleController = TextEditingController(text: widget.appointment.subject);
    _locationController = TextEditingController();
    _descriptionController = TextEditingController();
    _members = List<String>.from(widget.members);
    _startTime = widget.appointment.startTime;
    _endTime = widget.appointment.endTime;
    // Fetch the latest event duration from Google Calendar
    _fetchGoogleCalendarDuration();
  }

  // Fetch event start and end time from Google Calendar API
  Future<void> _fetchGoogleCalendarDuration() async {
    GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
    googleUser ??= await _googleSignIn.signIn();
    final auth = await googleUser!.authentication;
    final url =
        'https://www.googleapis.com/calendar/v3/calendars/primary/events/${widget.eventId}';
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${auth.accessToken}',
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final fetchedStart = DateTime.parse(data['start']['dateTime']);
      final fetchedEnd = DateTime.parse(data['end']['dateTime']);
      setState(() {
        _startTime = fetchedStart;
        _endTime = fetchedEnd;
      });
    }
  }

  // Update event details in Google Calendar
  Future<void> _updateGoogleCalendarEvent() async {
    GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
    googleUser ??= await _googleSignIn.signIn();
    final auth = await googleUser!.authentication;
    final Map<String, dynamic> eventPayload = {
      'summary': _titleController.text,
      'location': _locationController.text,
      'description': _descriptionController.text,
      'start': {
        'dateTime': _startTime!.toIso8601String(),
        'timeZone': DateTime.now().timeZoneName,
      },
      'end': {
        'dateTime': _endTime!.toIso8601String(),
        'timeZone': DateTime.now().timeZoneName,
      },
    };
    final url =
        'https://www.googleapis.com/calendar/v3/calendars/primary/events/${widget.eventId}';
    final response = await http.patch(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${auth.accessToken}',
      },
      body: jsonEncode(eventPayload),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          "Failed to update event to Google Calendar: ${response.body}");
    }
  }

  // Save event changes to both Google Calendar and Firestore
  Future<void> _saveEvent() async {
    if (_titleController.text.isEmpty ||
        _startTime == null ||
        _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    try {
      await _updateGoogleCalendarEvent();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update Google Calendar: $e")),
      );
      return;
    }

    final eventData = {
      'subject': _titleController.text,
      'location': _locationController.text,
      'description': _descriptionController.text,
      'startTime': _startTime,
      'endTime': _endTime,
      'members': _members,
    };

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.email != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.email)
          .collection('events')
          .doc(widget.eventId)
          .set(eventData, SetOptions(merge: true));
    }
    // After saving, return to the home screen
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  // Delete event from Google Calendar API
  Future<void> _deleteGoogleCalendarEvent() async {
    GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
    googleUser ??= await _googleSignIn.signIn();
    final auth = await googleUser!.authentication;
    final url =
        'https://www.googleapis.com/calendar/v3/calendars/primary/events/${widget.eventId}';
    final response = await http.delete(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${auth.accessToken}',
      },
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
          "Failed to delete event from Google Calendar: ${response.body}");
    }
  }

  // Delete event from both Google Calendar and Firestore
  Future<void> _deleteEvent() async {
    try {
      await _deleteGoogleCalendarEvent();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Failed to delete event from Google Calendar: $e")));
      return;
    }
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.email != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.email)
          .collection('events')
          .doc(widget.eventId)
          .delete();
    }
    // After deleting, return to the home screen
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  // Pick a contact from the device and add to members
  Future<void> _pickContact() async {
    final permissionGranted = await ContactPermission.request();
    if (!permissionGranted) return;

    try {
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null) return;

      final name = contact.name.first;
      final phone =
          contact.phones.isNotEmpty ? contact.phones.first.number : null;

      final displayText = phone != null ? '$name ($phone)' : name;

      if (!_members.contains(displayText)) {
        setState(() => _members.add(displayText));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  // Pick a new start time for the event
  Future<void> _pickTime() async {
    final current = _startTime ?? DateTime.now();
    final currentTime = TimeOfDay.fromDateTime(current);
    final picked =
        await showTimePicker(context: context, initialTime: currentTime);
    if (picked != null) {
      if (picked.hour == currentTime.hour &&
          picked.minute == currentTime.minute) return;
      final duration = (_startTime != null && _endTime != null)
          ? _endTime!.difference(_startTime!)
          : Duration.zero;
      setState(() {
        _startTime = DateTime(current.year, current.month, current.day,
            picked.hour, picked.minute);
        _endTime = _startTime!.add(duration);
      });
    }
  }

  // Pick a new duration for the event
  Future<void> _pickDuration() async {
    int selectedHours = 0;
    int selectedMinutes = 0;
    if (_startTime != null && _endTime != null) {
      final currentDuration = _endTime!.difference(_startTime!);
      selectedHours = currentDuration.inHours;
      selectedMinutes = currentDuration.inMinutes % 60;
    }
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Select Duration"),
              content: SizedBox(
                height: 200,
                child: Row(
                  children: [
                    // Hours picker
                    Expanded(
                      child: Column(
                        children: [
                          const Text("Hours"),
                          Expanded(
                            child: ListWheelScrollView.useDelegate(
                              itemExtent: 40,
                              onSelectedItemChanged: (index) {
                                setStateDialog(() {
                                  selectedHours = index;
                                });
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                builder: (context, index) {
                                  if (index < 0 || index > 12) return null;
                                  return Center(child: Text("$index"));
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Minutes picker
                    Expanded(
                      child: Column(
                        children: [
                          const Text("Minutes"),
                          Expanded(
                            child: ListWheelScrollView.useDelegate(
                              itemExtent: 40,
                              onSelectedItemChanged: (index) {
                                setStateDialog(() {
                                  selectedMinutes = index;
                                });
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                builder: (context, index) {
                                  if (index < 0 || index > 59) return null;
                                  return Center(child: Text("$index"));
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel")),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("OK")),
              ],
            );
          },
        );
      },
    );
    if (_startTime != null && _endTime != null) {
      final currentDuration = _endTime!.difference(_startTime!);
      final newDuration =
          Duration(hours: selectedHours, minutes: selectedMinutes);
      if (currentDuration == newDuration) return;
      setState(() {
        _endTime = _startTime!.add(newDuration);
      });
    }
  }

  // Pick a new start date for the event
  Future<void> _pickStartDate() async {
    if (_startTime == null) return;
    final current = _startTime!;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null &&
        (picked.year != current.year ||
            picked.month != current.month ||
            picked.day != current.day)) {
      final duration =
          _endTime != null ? _endTime!.difference(_startTime!) : Duration.zero;
      setState(() {
        _startTime = DateTime(picked.year, picked.month, picked.day,
            current.hour, current.minute);
        _endTime = _startTime!.add(duration);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Main UI for editing the event
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Event'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.black),
            onPressed: _saveEvent,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event title input
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: "Event Title",
                      labelStyle: TextStyle(color: Colors.black),
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 20),
                  // Location input
                  TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: "Location",
                      labelStyle: TextStyle(color: Colors.black),
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 20),
                  // Description input
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: "Description",
                      labelStyle: TextStyle(color: Colors.black),
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(color: Colors.black),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  // Event timing section
                  const Text(
                    'Event Timing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const Divider(color: Colors.black54, thickness: 1),
                  const SizedBox(height: 10),
                  // Row for picking date, time, and duration
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _pickStartDate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                          child: Text(
                            _startTime != null
                                ? "${_startTime!.toLocal().toString().substring(0, 10)}"
                                : "Set Date",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _pickTime,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                          child: Text(
                            _startTime != null
                                ? _startTime!
                                    .toLocal()
                                    .toString()
                                    .substring(11, 16)
                                : "Set Start Time",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _pickDuration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                          child: Text(
                            (_startTime != null && _endTime != null)
                                ? "${_endTime!.difference(_startTime!).inHours}h ${_endTime!.difference(_startTime!).inMinutes % 60}m"
                                : "Set Duration",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Members section
                  const Text(
                    'Members',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const Divider(color: Colors.black54, thickness: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Add or Remove Members",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.person_add, color: Colors.black),
                        onPressed: _pickContact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // List of current members
                  ..._members.map((member) => ListTile(
                        title: Text(member,
                            style: const TextStyle(color: Colors.black)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.black),
                          onPressed: () =>
                              setState(() => _members.remove(member)),
                        ),
                      )),
                  const SizedBox(height: 20),
                  // Action buttons: Save, Cancel, Delete
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveEvent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                          child: const Text("Save",
                              style: TextStyle(fontSize: 18)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          // Cancel returns to home screen
                          onPressed: () => Navigator.pushNamedAndRemoveUntil(
                              context, '/', (route) => false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                          child: const Text("Cancel",
                              style: TextStyle(fontSize: 18)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _deleteEvent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                          child: const Text("Delete",
                              style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
