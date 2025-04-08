import 'package:flutter/material.dart';
import 'main.dart';
import 'models.dart' as myModels; // use alias for Appointment type
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: [
    'email',
    'https://www.googleapis.com/auth/calendar.readonly',
    'https://www.googleapis.com/auth/calendar',
  ],
);

class EditEventPage extends StatefulWidget {
  final myModels.Appointment appointment; // updated type with alias
  final String eventId;
  final List<String> members;

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
    _titleController = TextEditingController(text: widget.appointment.subject);
    _locationController = TextEditingController();
    _descriptionController = TextEditingController();
    _members = List<String>.from(widget.members);
    _startTime = widget.appointment.startTime;
    _endTime = widget.appointment.endTime;
    _fetchGoogleCalendarDuration(); // fetch default duration from Google Calendar API
  }

  Future<void> _fetchGoogleCalendarDuration() async {
    GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
    if (googleUser == null) {
      googleUser = await _googleSignIn.signIn();
    }
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

  Future<void> _updateGoogleCalendarEvent() async {
    GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
    if (googleUser == null) {
      googleUser = await _googleSignIn.signIn();
    }
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
      // changed from put to patch
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
          .set(
              eventData,
              SetOptions(
                  merge:
                      true)); // merge updates so other fields remain unchanged
    }

    Navigator.of(context).pop(eventData);
  }

  Future<void> _deleteEvent() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.email != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.email)
          .collection('events')
          .doc(widget.eventId)
          .delete();
    }
    Navigator.of(context).pop({'delete': true});
  }

  Future<void> _pickContact() async {
    final permissionStatus = await Permission.contacts.request();
    if (!permissionStatus.isGranted) return;

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

  Future<void> _pickStartTimeDropdown() async {
    if (_startTime == null) return;
    int selectedHour = _startTime!.hour;
    int selectedMinute = _startTime!.minute;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Select Start Time"),
              content: Row(
                children: [
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedHour,
                      items: List.generate(24, (index) => index)
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text("$e")))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setStateDialog(() {
                            selectedHour = value;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedMinute,
                      items: List.generate(60, (index) => index)
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text("$e")))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setStateDialog(() {
                            selectedMinute = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
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
    // If there was no change, keep the same start time.
    if (selectedHour == _startTime!.hour &&
        selectedMinute == _startTime!.minute) return;
    final duration =
        _endTime != null ? _endTime!.difference(_startTime!) : Duration.zero;
    setState(() {
      _startTime = DateTime(_startTime!.year, _startTime!.month,
          _startTime!.day, selectedHour, selectedMinute);
      _endTime = _startTime!.add(duration);
    });
  }

  Future<void> _pickDurationDropdown() async {
    if (_startTime == null || _endTime == null) return;
    final currentDuration = _endTime!.difference(_startTime!);
    int selectedDurHour = currentDuration.inHours;
    int selectedDurMinute = currentDuration.inMinutes % 60;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Select Duration"),
              content: Row(
                children: [
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedDurHour,
                      items: List.generate(13, (index) => index)
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text("$e")))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setStateDialog(() {
                            selectedDurHour = value;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedDurMinute,
                      items: List.generate(60, (index) => index)
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text("$e")))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setStateDialog(() {
                            selectedDurMinute = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
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
    final newDuration =
        Duration(hours: selectedDurHour, minutes: selectedDurMinute);
    if (newDuration == currentDuration) return; // Unchanged duration.
    setState(() {
      _endTime = _startTime!.add(newDuration);
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _pickStartTimeDropdown,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                          child: Text(
                            _startTime != null
                                ? "${_startTime!.toLocal().toString().substring(0, 16)}"
                                : "Set Start Time",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _pickDurationDropdown,
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
                          onPressed: () => Navigator.of(context).pop(),
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
