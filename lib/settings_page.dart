import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: const Center(
        child: Text(
          "Settings Page",
          style: TextStyle(fontSize: 24, color: Colors.black),
        ),
      ),
    );
  }
}
