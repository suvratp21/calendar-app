import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  User? user;
  final TextEditingController _nameController = TextEditingController();

  Future<void> _signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return;
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      setState(() {
        user = userCredential.user;
      });
      print("Google sign in successful for user: ${user!.email}");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google sign in successful")));
    } catch (e) {
      print("Google sign in failed with error: ${e.toString()}");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Google sign in failed: ${e.toString()}")));
    }
  }

  Future<void> _submitName() async {
    if (_nameController.text.isEmpty || user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      'name': _nameController.text,
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Name successfully saved")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          PopupMenuButton(
            onSelected: (value) {
              if (value == 'add_name') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddNamePage(
                      user: user,
                      initialName: _nameController.text,
                    ),
                  ),
                ).then((result) {
                  if (result != null) {
                    setState(() {
                      _nameController.text = result;
                    });
                  }
                });
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'add_name',
                child: Text('Add Name'),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: user == null
            ? ElevatedButton(
                onPressed: _signInWithGoogle,
                child: const Text('Sign in with Google'),
              )
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Removed "Signed in as" text from home screen
                  ],
                ),
              ),
      ),
    );
  }
}

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
