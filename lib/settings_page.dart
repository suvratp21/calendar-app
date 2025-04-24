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

  String get notificationTimeLabel {
    if (_notificationMinutes < 60) {
      return "${_notificationMinutes} minutes";
    } else {
      final hours = _notificationMinutes ~/ 60;
      final minutes = _notificationMinutes % 60;
      if (minutes == 0) {
        return "$hours hour${hours > 1 ? 's' : ''}";
      }
      return "$hours hour${hours > 1 ? 's' : ''} $minutes minute${minutes > 1 ? 's' : ''}";
    }
  }

  Future<void> _showNotificationTimePicker(BuildContext context) async {
    List<int> standardTimes = [5, 10, 15, 30];
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        // Only show standard times and "Custom" (never show the current custom time as a disabled item)
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24, top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...standardTimes.map((min) => ListTile(
                      title: Text("$min minutes"),
                      onTap: () {
                        Navigator.pop(context);
                        _updateNotificationTime(min);
                      },
                    )),
                ListTile(
                  title: const Text(
                    "Custom",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await showDialog<Map<String, int>>(
                      context: context,
                      builder: (context) {
                        int hours = 0;
                        int minutes = 0;
                        return AlertDialog(
                          content: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: "Hours",
                                  ),
                                  keyboardType: TextInputType.number,
                                  controller: TextEditingController(text: "0"),
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
                                  controller: TextEditingController(text: "0"),
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
                      _updateNotificationTime((result["hours"] ?? 0) * 60 +
                          (result["minutes"] ?? 0));
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
      anchorPoint: Offset(
        0,
        MediaQuery.of(context).size.height,
      ),
    );
  }

  bool _isStandardTime(int min) => [5, 10, 15, 30].contains(min);

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
            title: Row(
              children: [
                const Text(
                  "Notification Time",
                  style: TextStyle(fontSize: 18, color: Colors.black),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    notificationTimeLabel,
                    style: const TextStyle(fontSize: 15, color: Colors.blue),
                  ),
                ),
              ],
            ),
            // Remove subtitle, since time is now adjacent to title
            onTap: () => _showNotificationTimePicker(context),
            trailing: const Icon(Icons.arrow_drop_down),
          ),
        ],
      ),
    );
  }
}
