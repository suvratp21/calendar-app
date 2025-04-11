import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart'; // added import
import 'package:cloud_firestore/cloud_firestore.dart'; // added import

class AddEventPage extends StatefulWidget {
  const AddEventPage({super.key});

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: [
    'email',
    'https://www.googleapis.com/auth/calendar.readonly',
    'https://www.googleapis.com/auth/calendar',
  ],
);

class _AddEventPageState extends State<AddEventPage> {
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _descriptionController;
  final List<String> _members = [];
  DateTime? _startTime;
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: "(no title)");
    _locationController = TextEditingController(text: "");
    _descriptionController = TextEditingController();
    _startTime = DateTime.now().add(Duration(hours: 1));
    _endTime = _startTime!.add(Duration(hours: 1));
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

  Future<void> _saveGoogleCalendarEvent() async {
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
        'https://www.googleapis.com/calendar/v3/calendars/primary/events';
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${auth.accessToken}',
      },
      body: jsonEncode(eventPayload),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          "Failed to add event to Google Calendar: ${response.body}");
    }
  }

  Future<void> _saveEvent() async {
    // Build event data without members for saving in Firebase.
    final eventData = {
      'subject': _titleController.text,
      'location': _locationController.text,
      'description': _descriptionController.text,
      'startTime': _startTime,
      'endTime': _endTime,
    };

    try {
      // First, save event in Google Calendar API (members not included).
      await _saveGoogleCalendarEvent();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Event successfully saved")),
      );
      // Save event data to Firebase without members.
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.email != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.email)
            .collection('events')
            .add(eventData);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save to Google Calendar: $e")),
      );
    }
    // Pass eventData with members for display in the app.
    Navigator.of(context).pop({...eventData, 'members': _members});
  }

  Future<void> _pickDate() async {
    final current = _startTime ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      if (picked.year == current.year &&
          picked.month == current.month &&
          picked.day == current.day) {
        return; // No change in date.
      }
      final duration = (_startTime != null && _endTime != null)
          ? _endTime!.difference(_startTime!)
          : Duration.zero;
      setState(() {
        _startTime = DateTime(picked.year, picked.month, picked.day,
            current.hour, current.minute);
        _endTime = _startTime!.add(duration);
      });
    }
  }

  Future<void> _pickTime() async {
    final current = _startTime ?? DateTime.now();
    final currentTime = TimeOfDay.fromDateTime(current);
    final picked =
        await showTimePicker(context: context, initialTime: currentTime);
    if (picked != null) {
      if (picked.hour == currentTime.hour &&
          picked.minute == currentTime.minute) {
        return; // No change in time.
      }
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
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
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
      if (currentDuration == newDuration) return; // Unchanged duration.
      setState(() {
        _endTime = _startTime!.add(newDuration);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Event"),
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
          elevation: 5,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
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
                        color: Colors.black),
                  ),
                  const Divider(color: Colors.black54, thickness: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _pickDate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                          child: Text(
                            _startTime != null
                                ? "${_startTime!.year}-${_startTime!.month.toString().padLeft(2, '0')}-${_startTime!.day.toString().padLeft(2, '0')}"
                                : "Date",
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
                                ? "${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}"
                                : "Time",
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
                            _startTime != null && _endTime != null
                                ? "${_endTime!.difference(_startTime!).inHours}h ${_endTime!.difference(_startTime!).inMinutes % 60}m"
                                : "Duration",
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
                        color: Colors.black),
                  ),
                  const Divider(color: Colors.black54, thickness: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Add or Remove Members",
                        style: TextStyle(fontSize: 16, color: Colors.black),
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
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'uniqueAddEventFAB', // ensure this tag is unique app-wide
        onPressed: _saveEvent,
        child: const Icon(Icons.save),
      ),
    );
  }
}
