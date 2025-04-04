import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'notification_service.dart';
import 'package:flutter/material.dart';

Future<List<Appointment>> fetchCalendarEvents(
    String accessToken, DateTime date) async {
  DateTime startDate = DateTime(date.year, date.month, date.day)
      .subtract(const Duration(days: 5));
  DateTime endDate =
      DateTime(date.year, date.month, date.day).add(const Duration(days: 5));
  final url = Uri.parse(
      'https://www.googleapis.com/calendar/v3/calendars/primary/events?maxResults=250&orderBy=startTime&singleEvents=true&timeMin=${startDate.toUtc().toIso8601String()}&timeMax=${endDate.toUtc().toIso8601String()}');
  try {
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $accessToken'
    }).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final events = data['items'] as List<dynamic>;
      List<Appointment> appointments = [];
      for (var event in events) {
        try {
          String? startStr =
              event['start']['dateTime'] ?? event['start']['date'];
          String? endStr = event['end']?['dateTime'] ?? event['end']?['date'];
          if (startStr != null) {
            DateTime startTime = DateTime.parse(startStr).toLocal();
            DateTime endTime = endStr != null
                ? DateTime.parse(endStr).toLocal()
                : startTime.add(const Duration(hours: 1));
            Appointment appt = Appointment(
              startTime: startTime,
              endTime: endTime,
              subject: event['summary'] ?? 'No Title',
              color: Colors.blue,
              eventId: event['id'] ?? '',
            );
            appointments.add(appt);
            await scheduleNotification(appt);
            print(
                'Event: ${event['summary']}, Start: $startTime, End: $endTime');
          }
        } catch (e) {
          print('Error parsing event: $e');
        }
      }
      return appointments;
    } else {
      print('Failed to fetch calendar events: ${response.body}');
      return [];
    }
  } on TimeoutException catch (_) {
    print('Request to fetch calendar events timed out.');
    return [];
  } catch (e) {
    print('Error fetching calendar events: $e');
    return [];
  }
}

Future<void> updateGoogleCalendarEvent(
    String accessToken, Appointment appointment) async {
  if (accessToken.isEmpty || appointment.eventId.isEmpty) return;
  final url = Uri.parse(
      'https://www.googleapis.com/calendar/v3/calendars/primary/events/${appointment.eventId}');
  final body = json.encode({
    'summary': appointment.subject,
    'start': {'dateTime': appointment.startTime.toUtc().toIso8601String()},
    'end': {'dateTime': appointment.endTime.toUtc().toIso8601String()},
  });
  try {
    final response = await http.patch(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json'
      },
      body: body,
    );
    if (response.statusCode == 200) {
      print('Google event updated successfully.');
      print('DEBUG: Updated event data: $body');
    } else {
      print('Failed to update Google event: ${response.body}');
    }
  } catch (e) {
    print('Error updating Google event: $e');
  }
}
