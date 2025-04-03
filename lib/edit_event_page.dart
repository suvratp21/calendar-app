import 'package:flutter/material.dart';
import 'main.dart'; // Import the Appointment class

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

    Navigator.of(context).pop({
      'subject': _titleController.text,
      'startTime': _startTime,
      'endTime': _endTime,
      'members': _members,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Event'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveEvent,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Event Title"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: "Location"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: "Description"),
              ),
              const SizedBox(height: 10),
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
                          setState(() {
                            _startTime = pickedDate;
                          });
                        }
                      },
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
                          setState(() {
                            _endTime = pickedDate;
                          });
                        }
                      },
                      child: const Text("Pick End Time"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                "Members",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Column(
                children: _members
                    .map((member) => ListTile(
                          title: Text(member),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              setState(() {
                                _members.remove(member);
                              });
                            },
                          ),
                        ))
                    .toList(),
              ),
              ElevatedButton(
                onPressed: () {
                  // Add logic to add a new member
                },
                child: const Text("Add Member"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
