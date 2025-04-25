import 'package:permission_handler/permission_handler.dart';

// Utility class to handle contact permission requests
class ContactPermission {
  // Requests contact permission and returns true if granted
  static Future<bool> request() async {
    PermissionStatus status = await Permission.contacts.request();
    return status.isGranted;
  }
}
