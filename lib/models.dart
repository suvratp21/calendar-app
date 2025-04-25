import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

// Represents a calendar appointment/event
class Appointment {
  Appointment({
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.color,
    required this.eventId,
    this.attendees,
  });
  DateTime startTime;
  DateTime endTime;
  String subject;
  final Color color;
  final String eventId;
  final List<String>? attendees; // List of attendee emails (optional)
}

// Data source for the Syncfusion calendar widget
class AppointmentDataSource extends CalendarDataSource {
  AppointmentDataSource(List<Appointment> source) {
    appointments = source;
  }
  @override
  DateTime getStartTime(int index) => appointments![index].startTime;
  @override
  DateTime getEndTime(int index) => appointments![index].endTime;
  @override
  String getSubject(int index) => appointments![index].subject;
  @override
  Color getColor(int index) => appointments![index].color;
}
