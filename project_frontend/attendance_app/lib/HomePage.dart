import 'package:attendance_app/permissions.dart';
import 'package:attendance_app/student_app/student_homepage.dart';
import 'package:attendance_app/teacher_app/teachers_homepage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'global_variable/base_url.dart'; // ✅ import the global config

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _urlController = TextEditingController();
  String _statusMessage = "";
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();

    // ✅ Ask for permissions at startup
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      bool granted = await AppPermissions.requestAllPermissions(context);
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "⚠️ Some permissions were not granted. App may not work properly.",
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  Future<void> _checkBackend() async {
    final baseUrl = _urlController.text.trim();

    if (baseUrl.isEmpty) {
      setState(() {
        _statusMessage = "❌ Please enter a base URL.";
      });
      return;
    }

    // ✅ Test mode: skip actual HTTP request
    if (baseUrl.toLowerCase() == "test") {
      setState(() {
        _isConnected = true;
        _statusMessage =
            "🧪 Test mode: Connected!\nBackend says: This is testing.";
      });
      BaseUrl.value = baseUrl; // ✅ save globally
      return;
    }

    try {
      final response = await http.get(Uri.parse(baseUrl));

      if (response.statusCode == 200) {
        setState(() {
          _isConnected = true;
          _statusMessage =
              "✅ Connected successfully!\nBackend says: ${response.body}";
        });
        BaseUrl.value = baseUrl; // ✅ save globally
      } else {
        setState(() {
          _isConnected = false;
          _statusMessage =
              "⚠️ Failed to connect. Status code: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _statusMessage = "❌ Error: $e";
      });
    }
  }

  void _goToTeacherApp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TeachersHomePage()),
    );
  }

  void _goToStudentApp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StudentHomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Smart Attendance - Home")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Enter Backend Base URL",
                hintText: "http://192.168.x.x:8000/   OR   test",
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: _checkBackend,
              child: const Text("Connect Backend"),
            ),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            if (_isConnected) ...[
              ElevatedButton.icon(
                onPressed: _goToTeacherApp,
                icon: const Icon(Icons.school),
                label: const Text("Teacher App"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                onPressed: _goToStudentApp,
                icon: const Icon(Icons.person),
                label: const Text("Student App"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
