import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddNamePage extends StatefulWidget {
  final User? user;
  final String initialName;
  const AddNamePage({super.key, required this.user, required this.initialName});

  @override
  State<AddNamePage> createState() => _AddNamePageState();
}

class _AddNamePageState extends State<AddNamePage> {
  late TextEditingController _pageNameController;

  @override
  void initState() {
    super.initState();
    _pageNameController = TextEditingController(text: widget.initialName);
    if (widget.user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please sign in first")));
        Navigator.of(context).pop();
      });
    }
  }

  Future<void> _saveName() async {
    if (_pageNameController.text.isEmpty || widget.user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user!.uid)
        .set({'name': _pageNameController.text});
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Name successfully saved")));
    Navigator.of(context).pop(_pageNameController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Name")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _pageNameController,
              decoration: const InputDecoration(labelText: "Enter your name"),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveName,
                    child: const Text("Save"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Cancel"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
