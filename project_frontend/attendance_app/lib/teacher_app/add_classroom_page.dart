import 'dart:convert';
import 'package:attendance_app/global_variable/base_url.dart';
import 'package:attendance_app/global_variable/token_handles.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AddClassroomPage extends StatefulWidget {
  const AddClassroomPage({super.key});

  @override
  State<AddClassroomPage> createState() => _AddClassroomPageState();
}

class _AddClassroomPageState extends State<AddClassroomPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String _statusMessage = "";

  Future<void> _createClassroom() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();

    if (name.isEmpty || code.isEmpty) {
      setState(() {
        _statusMessage = "⚠️ Please fill in all fields.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "";
    });

    try {
      final response = await http.post(
        Uri.parse("${BaseUrl.value}/user/teacher/classrooms/"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${TokenHandles.accessToken}",
        },
        body: jsonEncode({"name": name, "code": code}),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final classroomId = data["id"];

        setState(() {
          _statusMessage = "✅ Classroom created! ID: $classroomId";
        });

        // Navigate back to Dashboard and tell it to reload
        Navigator.pop(context, true);
      } else {
        setState(() {
          _statusMessage = "❌ Failed: ${response.statusCode}\n${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "❌ Error: $e";
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Classroom")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Class Name",
                hintText: "e.g., Database Management Systems",
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Class Code",
                hintText: "e.g., DBMS101",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _createClassroom,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Create Classroom"),
            ),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
