import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// SettingsPage allows users to configure notification time and default messages
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

// NotificationService for updating notification time (used for demonstration/logging)
class NotificationService {
  static void updateDefaultNotificationTime(int minutes) {
    debugPrint('Notification time updated to $minutes minutes');
  }
}

class _SettingsPageState extends State<SettingsPage> {
  int _notificationMinutes = 10; // Default notification time in minutes

  // Controllers for the default message text fields
  final TextEditingController _runningLateController = TextEditingController();
  final TextEditingController _postponeController = TextEditingController();

  // Default message templates
  String _defaultRunningLate = 'Regarding "{event}": I will be late.';
  String _defaultPostpone = 'Regarding "{event}": The event is postponed.';

  @override
  void initState() {
    super.initState();
    // Load saved settings when the page is initialized
    _loadNotificationTime();
    _loadDefaultMessages();
  }

  // Load default messages from persistent storage
  Future<void> _loadDefaultMessages() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _defaultRunningLate = prefs.getString('defaultRunningLate') ??
          'Regarding "{event}": I will be late.';
      _defaultPostpone = prefs.getString('defaultPostpone') ??
          'Regarding "{event}": The event is postponed.';
      _runningLateController.text = _defaultRunningLate;
      _postponeController.text = _defaultPostpone;
    });
  }

  // Save default messages to persistent storage
  Future<void> _saveDefaultMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('defaultRunningLate', _runningLateController.text);
    await prefs.setString('defaultPostpone', _postponeController.text);
    setState(() {
      _defaultRunningLate = _runningLateController.text;
      _defaultPostpone = _postponeController.text;
    });
  }

  // Load notification time from persistent storage
  Future<void> _loadNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationMinutes = prefs.getInt('notificationMinutes') ?? 10;
    });
  }

  // Save notification time to persistent storage
  Future<void> _saveNotificationTime(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notificationMinutes', minutes);
  }

  // Update notification time and persist the change
  void _updateNotificationTime(int minutes) {
    setState(() {
      _notificationMinutes = minutes;
    });
    _saveNotificationTime(minutes);
    NotificationService.updateDefaultNotificationTime(minutes);
  }

  // Display label for notification time (e.g., "10 minutes" or "1 hour 15 minutes")
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

  // Show a bottom sheet to pick notification time (standard or custom)
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
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24, top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Standard time options
                ...standardTimes.map((min) => ListTile(
                      title: Text("$min minutes"),
                      onTap: () {
                        Navigator.pop(context);
                        _updateNotificationTime(min);
                      },
                    )),
                // Custom time option
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
                              // Input for hours
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
                              // Input for minutes
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

  // Helper to check if a time is a standard option
  bool _isStandardTime(int min) => [5, 10, 15, 30].contains(min);

  @override
  Widget build(BuildContext context) {
    // Main UI for settings page
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Notification time setting
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
              onTap: () => _showNotificationTimePicker(context),
              trailing: const Icon(Icons.arrow_drop_down),
            ),
            const Divider(height: 32),
            // Default messages section
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // Running late message input
                  TextField(
                    controller: _runningLateController,
                    decoration: const InputDecoration(
                      labelText: 'Running Late Message',
                    ),
                    onChanged: (val) => _saveDefaultMessages(),
                    minLines: 1,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: 12),
                  // Postpone message input
                  TextField(
                    controller: _postponeController,
                    decoration: const InputDecoration(
                      labelText: 'Postpone Message',
                      helperText: 'Use {event} using event name.',
                    ),
                    onChanged: (val) => _saveDefaultMessages(),
                    minLines: 1,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Dispose controllers to free resources
    _runningLateController.dispose();
    _postponeController.dispose();
    super.dispose();
  }
}
