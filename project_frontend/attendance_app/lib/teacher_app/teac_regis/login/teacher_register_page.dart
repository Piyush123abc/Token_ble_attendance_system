import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:attendance_app/global_variable/base_url.dart';

class TeacherRegisterPage extends StatefulWidget {
  const TeacherRegisterPage({super.key});

  @override
  State<TeacherRegisterPage> createState() => _TeacherRegisterPageState();
}

class _TeacherRegisterPageState extends State<TeacherRegisterPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _uidController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();

  bool _isLoading = false;

  Future<void> _registerTeacher() async {
    final url = "${BaseUrl.value}/user/register/teacher/";
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": _usernameController.text.trim(),
          "password": _passwordController.text.trim(),
          "uid": _uidController.text.trim(),
          "department": _departmentController.text.trim(),
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // ✅ Success dialog
        _showDialog(
          title: "Success",
          message: "Registration successful!",
          isSuccess: true,
        );
      } else {
        // ⚠️ Error dialog with server response
        _showDialog(
          title: "Error",
          message: "Failed: ${response.statusCode}\n${response.body}",
          isSuccess: false,
        );
      }
    } catch (e) {
      _showDialog(
        title: "Error",
        message: "Something went wrong:\n$e",
        isSuccess: false,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showDialog({
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            title,
            style: TextStyle(color: isSuccess ? Colors.green : Colors.red),
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                if (isSuccess) {
                  Navigator.of(context).pop(); // pop registration page
                }
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Register")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Username",
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Password",
                ),
                obscureText: true,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _uidController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "UID",
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _departmentController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Department",
                ),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _registerTeacher,
                      child: const Text("Register"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
