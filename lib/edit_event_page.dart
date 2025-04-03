import 'package:flutter/material.dart';
import 'main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class EditEventPage extends StatefulWidget {
  final Appointment appointment;
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
          .set(eventData);
    }

    Navigator.of(context).pop(eventData);
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

      final displayText = phone != null ? '$name (${phone})' : name;

      if (!_members.contains(displayText)) {
        setState(() => _members.add(displayText));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
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
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: "Event Title",
                      labelStyle: TextStyle(color: Colors.black),
                    ),
                    style: const TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: "Location",
                      labelStyle: TextStyle(color: Colors.black),
                    ),
                    style: const TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: "Description",
                      labelStyle: TextStyle(color: Colors.black),
                    ),
                    style: const TextStyle(color: Colors.black),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: _startTime ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (pickedDate != null) {
                              setState(() => _startTime = pickedDate);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text("Pick Start Time"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: _endTime ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (pickedDate != null) {
                              setState(() => _endTime = pickedDate);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text("Pick End Time"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Members",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                      ),
                      IconButton(
                        icon: const Icon(Icons.person_add, color: Colors.black),
                        onPressed: _pickContact,
                      ),
                    ],
                  ),
                  ..._members
                      .map((member) => ListTile(
                            title: Text(member,
                                style: const TextStyle(color: Colors.black)),
                            trailing: IconButton(
                              icon:
                                  const Icon(Icons.close, color: Colors.black),
                              onPressed: () =>
                                  setState(() => _members.remove(member)),
                            ),
                          ))
                      .toList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
