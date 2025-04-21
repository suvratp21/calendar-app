import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class NotificationService {
  static void updateDefaultNotificationTime(int minutes) {
    // Implement the update logic here.
    debugPrint('Notification time updated to $minutes minutes');
  }
}

class _SettingsPageState extends State<SettingsPage> {
  int _notificationMinutes = 10; // default value

  @override
  void initState() {
    super.initState();
    _loadNotificationTime(); // Load saved notification time on initialization
  }

  Future<void> _loadNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationMinutes = prefs.getInt('notificationMinutes') ?? 10;
    });
  }

  Future<void> _saveNotificationTime(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notificationMinutes', minutes);
  }

  void _updateNotificationTime(int minutes) {
    setState(() {
      _notificationMinutes = minutes;
    });
    _saveNotificationTime(minutes); // Save the updated notification time
    NotificationService.updateDefaultNotificationTime(minutes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          ListTile(
            title: const Text(
              "Notification Time",
              style: TextStyle(fontSize: 18, color: Colors.black),
            ),
            trailing: DropdownButton<int>(
              value: _notificationMinutes,
              items: const [
                DropdownMenuItem(value: 5, child: Text("5 minutes")),
                DropdownMenuItem(value: 10, child: Text("10 minutes")),
                DropdownMenuItem(value: 15, child: Text("15 minutes")),
                DropdownMenuItem(value: 30, child: Text("30 minutes")),
                DropdownMenuItem(
                    value: -1, child: Text("Custom")), // Custom option
              ],
              onChanged: (value) async {
                if (value == -1) {
                  // Show dialog for custom input
                  final result = await showDialog<Map<String, int>>(
                    context: context,
                    builder: (context) {
                      int hours = 0; // Default to 0
                      int minutes = 0; // Default to 0
                      return AlertDialog(
                        content: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: "Hours",
                                ),
                                keyboardType: TextInputType.number,
                                controller: TextEditingController(
                                    text: "0"), // Default value
                                onChanged: (val) {
                                  hours = int.tryParse(val) ?? 0;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: "Minutes",
                                ),
                                keyboardType: TextInputType.number,
                                controller: TextEditingController(
                                    text: "0"), // Default value
                                onChanged: (val) {
                                  minutes = int.tryParse(val) ?? 0;
                                },
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop({
                              "hours": hours,
                              "minutes": minutes,
                            }),
                            child: const Text("OK"),
                          ),
                        ],
                      );
                    },
                  );

                  if (result != null) {
                    _updateNotificationTime(
                        (result["hours"] ?? 0) * 60 + (result["minutes"] ?? 0));
                  }
                } else if (value != null) {
                  _updateNotificationTime(value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
