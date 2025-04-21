import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_event_page.dart'; // Import the edit event page
// Import the Appointment class
import 'models.dart' as myModels; // use alias to avoid conflict

class EventDetailsPage extends StatefulWidget {
  final myModels.Appointment appointment; // updated type with alias
  final String eventId; // Unique event ID for Firebase
  final List<String>? attendees; // new field

  const EventDetailsPage({
    super.key,
    required this.appointment,
    required this.eventId,
    this.attendees, // new parameter
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
    final List<String> attendees =
        widget.attendees ?? widget.appointment.attendees ?? [];

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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0), // increased overall padding
          child: Card(
            elevation: 10,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20.0), // generous inner padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event Title Section
                  ListTile(
                    leading:
                        const Icon(Icons.event, color: Colors.black, size: 32),
                    title: Text(
                      widget.appointment.subject,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Timing Section using ListTiles
                  ListTile(
                    leading: const Icon(Icons.access_time, color: Colors.black),
                    title: const Text(
                      'Start Time:',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      widget.appointment.startTime.toString(),
                      style:
                          const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer, color: Colors.black),
                    title: const Text(
                      'Duration:',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${duration.inHours} hrs ${duration.inMinutes % 60} mins',
                      style:
                          const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.black54, thickness: 1),
                  const SizedBox(height: 10),
                  // Members Section
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text(
                      'Members:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  members.isNotEmpty
                      ? Column(
                          children: members.map((member) {
                            return ListTile(
                              leading:
                                  const Icon(Icons.person, color: Colors.black),
                              title: Text(
                                member,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            );
                          }).toList(),
                        )
                      : const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            'No members added.',
                            style:
                                TextStyle(fontSize: 16, color: Colors.black87),
                          ),
                        ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.black54, thickness: 1),
                  const SizedBox(height: 10),
                  // Attendees Section
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text(
                      'Attendees:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  attendees.isNotEmpty
                      ? Column(
                          children: attendees.map((attendee) {
                            return ListTile(
                              leading:
                                  const Icon(Icons.people, color: Colors.black),
                              title: Text(
                                attendee,
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.black),
                              ),
                            );
                          }).toList(),
                        )
                      : const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            'No attendees available.',
                            style:
                                TextStyle(fontSize: 16, color: Colors.black87),
                          ),
                        ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.black54, thickness: 1),
                  const SizedBox(height: 10),
                  // Additional Information Section
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text(
                      'Additional Information:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'No additional information available.',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
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
