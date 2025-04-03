import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart'; // Import the Appointment class

class EventDetailsPage extends StatefulWidget {
  final Appointment appointment;
  final String eventId; // Unique event ID for Firebase

  const EventDetailsPage({
    super.key,
    required this.appointment,
    required this.eventId,
  });

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  List<String> members = [];

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final eventDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.email)
        .collection('events')
        .doc(widget.eventId)
        .get();

    if (eventDoc.exists) {
      final data = eventDoc.data();
      if (data != null && data['members'] != null) {
        setState(() {
          members = List<String>.from(data['members']);
        });
      }
    }
  }

  Future<void> _editEvent() async {
    // Navigate to an edit event page (to be implemented)
    // Pass the event details and eventId for editing
  }

  @override
  Widget build(BuildContext context) {
    final Duration duration =
        widget.appointment.endTime.difference(widget.appointment.startTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editEvent, // Edit button
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Title: ${widget.appointment.subject}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Start Time: ${widget.appointment.startTime}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                'Duration: ${duration.inHours} hours and ${duration.inMinutes % 60} minutes',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              const Text(
                'Time Zone: Not specified',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              const Text(
                'Location: Not specified',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              const Text(
                'Description: Not available',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              const Text(
                'Members:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              members.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: members
                          .map((member) => Text(
                                member,
                                style: const TextStyle(fontSize: 16),
                              ))
                          .toList(),
                    )
                  : const Text(
                      'No members added.',
                      style: TextStyle(fontSize: 16),
                    ),
              const SizedBox(height: 20),
              const Text(
                'Google Drive Attachments:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'No attachments available.',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
