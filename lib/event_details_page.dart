import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_event_page.dart'; // Import the edit event page
import 'main.dart'; // Import the Appointment class
import 'models.dart' as myModels; // use alias to avoid conflict

class EventDetailsPage extends StatefulWidget {
  final myModels.Appointment appointment; // updated type with alias
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
    final updatedEvent = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditEventPage(
          appointment: widget.appointment,
          eventId: widget.eventId,
          members: members,
        ),
      ),
    );

    if (updatedEvent != null) {
      setState(() {
        widget.appointment.subject = updatedEvent['subject'];
        widget.appointment.startTime = updatedEvent['startTime'];
        widget.appointment.endTime = updatedEvent['endTime'];
        members = updatedEvent['members'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Duration duration =
        widget.appointment.endTime.difference(widget.appointment.startTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: _editEvent,
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
                  Row(
                    children: [
                      const Icon(Icons.event, color: Colors.black, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        widget.appointment.subject,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          color: Colors.black, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Start Time: ${widget.appointment.startTime}',
                          style: const TextStyle(
                              fontSize: 16, color: Colors.black),
                          overflow: TextOverflow.ellipsis, // Prevent overflow
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.black, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Duration: ${duration.inHours} hours and ${duration.inMinutes % 60} minutes',
                          style: const TextStyle(
                              fontSize: 16, color: Colors.black),
                          overflow: TextOverflow.ellipsis, // Prevent overflow
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.black54, thickness: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.people, color: Colors.black, size: 24),
                      const SizedBox(width: 10),
                      const Text(
                        'Members:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  members.isNotEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: members
                              .map((member) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.person,
                                            color: Colors.black, size: 20),
                                        const SizedBox(width: 10),
                                        Text(
                                          member,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        )
                      : const Text(
                          'No members added.',
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.black54, thickness: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.info, color: Colors.black, size: 24),
                      const SizedBox(width: 10),
                      const Text(
                        'Additional Information:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No additional information available.',
                    style: TextStyle(fontSize: 16, color: Colors.black),
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
