import 'dart:convert';
import 'package:attendance_app/student_app/student_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../global_variable/base_url.dart';
import '../../../global_variable/token_handles.dart';
import '../../../global_variable/student_profile.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1️⃣ Login request
      final response = await http.post(
        Uri.parse("${BaseUrl.value}/user/login/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": _usernameController.text.trim(),
          "password": _passwordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final access = data["access"];
        final refresh = data["refresh"];

        // Save tokens
        TokenHandles.setTokens(access, refresh);

        // 2️⃣ Fetch profile after login
        final profileHeaders = await TokenHandles.getAuthHeaders();
        final profileRes = await http.get(
          Uri.parse("${BaseUrl.value}/user/profile/"),
          headers: profileHeaders,
        );

        if (profileRes.statusCode == 200) {
          final profileData = jsonDecode(profileRes.body);
          final studentProfile = StudentProfile(
            id: profileData['id'],
            uid: profileData['uid'],
            username: profileData['username'],
            branch: profileData['branch'] ?? '',
            authKey: profileData['auth_key'],
          );
          GlobalStudentProfile.setProfile(studentProfile);

          // 3️⃣ Navigate to dashboard
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => StudentDashboardPage(
                  // classroomId: 0, // Replace with actual classroomId if needed
                ),
              ),
            );
          }
        } else {
          setState(() {
            _error =
                "Failed to fetch profile (Status: ${profileRes.statusCode})";
          });
        }
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _error = data["detail"] ?? "Login failed";
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Student Login")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: "Username"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Login"),
            ),
          ],
        ),
      ),
    );
  }
}
