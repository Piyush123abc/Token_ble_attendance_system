// lib/teacher_app/teacher_login_page.dart
import 'dart:convert';
import 'package:attendance_app/global_variable/teacher_profile.dart';
import 'package:attendance_app/teacher_app/teacher_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../global_variable/base_url.dart';
import '../../../global_variable/token_handles.dart';

class TeacherLoginPage extends StatefulWidget {
  const TeacherLoginPage({super.key});

  @override
  State<TeacherLoginPage> createState() => _TeacherLoginPageState();
}

class _TeacherLoginPageState extends State<TeacherLoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _statusMessage = "";
  bool _isLoading = false;

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
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
      // 1️⃣ Login request
      final response = await http.post(
        Uri.parse("${BaseUrl.value}user/login/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data.containsKey("access") && data.containsKey("refresh")) {
          TokenHandles.setTokens(data["access"], data["refresh"]);

          setState(() => _statusMessage = "✅ Login successful!");

          // 2️⃣ Fetch teacher profile after login
          final profileResponse = await http.get(
            Uri.parse("${BaseUrl.value}user/profile/"),
            headers: await TokenHandles.getAuthHeaders(),
          );

          if (profileResponse.statusCode == 200) {
            final profileData = jsonDecode(profileResponse.body);

            // Store in global variable
            GlobalStore.teacherProfile = profileData;

            // Navigate to dashboard
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TeacherDashboard()),
            );
          } else {
            setState(() {
              _statusMessage =
                  "⚠️ Failed to load profile: ${profileResponse.body}";
            });
          }
        } else {
          setState(() {
            _statusMessage = "⚠️ Unexpected login response: ${response.body}";
          });
        }
      } else {
        setState(() {
          _statusMessage =
              "❌ Login failed. Status: ${response.statusCode}\n${response.body}";
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
      appBar: AppBar(title: const Text("Teacher Login")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
              obscureText: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Password",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Login"),
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
