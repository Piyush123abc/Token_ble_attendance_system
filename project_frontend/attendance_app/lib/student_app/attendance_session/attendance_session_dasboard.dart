import 'dart:convert';
import 'package:attendance_app/global_variable/base_url.dart';
import 'package:attendance_app/global_variable/student_profile.dart';
import 'package:attendance_app/global_variable/token_handles.dart';
import 'package:attendance_app/student_app/attendance_session/add_to_exception_list.dart';
import 'package:attendance_app/student_app/attendance_session/token_passing.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:http/http.dart' as http;

/// Attendance Session Page
/// This page is shown when a student wants to join a specific classroom session.
/// Steps:
/// 1. Verify fingerprint authentication.
/// 2. Check if fingerprint/password has changed.
/// 3. If authenticated, show session options: Pass Token / Add to Exception List.
class AttendanceSessionPage extends StatefulWidget {
  final int classroomId;
  final String classroomName;
  final String classroomCode;

  const AttendanceSessionPage({
    super.key,
    required this.classroomId,
    required this.classroomName,
    required this.classroomCode,
  });

  @override
  State<AttendanceSessionPage> createState() => _AttendanceSessionPageState();
}

class _AttendanceSessionPageState extends State<AttendanceSessionPage> {
  final LocalAuthentication auth = LocalAuthentication(); // Local_auth instance
  bool _loading = true; // Loading indicator for async operations

  String? _errorMessage; // Stores any error messages for display

  @override
  void initState() {
    super.initState();

    // --------------------------
    // For testing: skip fingerprint verification
    // --------------------------
    // _verifyStudent(); // Commented out
    _loading = false; // Directly show session actions
  }

  /// Verifies the student identity using fingerprint authentication and backend check
  Future<void> _verifyStudent() async {
    try {
      // --------------------------
      // Step 1: Check if device supports fingerprint
      // --------------------------
      bool canCheckBiometrics = await auth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        setState(() {
          _errorMessage = "Device has no fingerprint sensor.";
          _loading = false;
        });
        return;
      }

      // --------------------------
      // Step 2: Authenticate user via fingerprint
      // --------------------------
      bool didAuthenticate = await auth.authenticate(
        localizedReason: "Authenticate to join attendance session",
        options: const AuthenticationOptions(
          stickyAuth: true, // Keeps auth alive if app goes to background
          biometricOnly: true, // Only allow biometrics
        ),
      );

      if (!didAuthenticate) {
        setState(() {
          _errorMessage = "Fingerprint authentication failed.";
          _loading = false;
        });
        return;
      }

      // --------------------------
      // Step 3: Fetch student profile from backend
      // --------------------------
      final headers = await TokenHandles.getAuthHeaders(); // JWT headers
      final profileRes = await http.get(
        Uri.parse("${BaseUrl.value}/user/profile/"),
        headers: headers,
      );

      if (profileRes.statusCode != 200) {
        setState(() {
          _errorMessage = "Failed to fetch profile: ${profileRes.statusCode}";
          _loading = false;
        });
        return;
      }

      final profileData = jsonDecode(profileRes.body);
      final authKeyBackend = profileData['auth_key']; // Key stored in backend

      // --------------------------
      // Step 4: Generate device fingerprint key
      // --------------------------
      final fingerprintKey = await _generateFingerprintKey();

      // --------------------------
      // Step 5: Validate key with backend
      // --------------------------
      if (authKeyBackend != fingerprintKey) {
        setState(() {
          _errorMessage = "Fingerprint/password changed or mismatch detected.";
          _loading = false;
        });
        return;
      }

      // --------------------------
      // Success → allow access to session options
      // --------------------------
      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error: $e";
        _loading = false;
      });
    }
  }

  /// Placeholder for generating the device's fingerprint key
  /// TODO: Replace this with actual fingerprint-based key logic
  Future<String> _generateFingerprintKey() async {
    // You can implement logic like hashing a unique device ID or biometric template
    return "dummy_fingerprint_key";
  }

  @override
  Widget build(BuildContext context) {
    // --------------------------
    // Show loading spinner while verifying
    // --------------------------
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // --------------------------
    // Show error screen if verification fails
    // --------------------------
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Attendance Session")),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(context), // Return to previous page
                child: const Text("OK"),
              ),
            ],
          ),
        ),
      );
    }

    // --------------------------
    // Authenticated → show session actions
    // --------------------------
    return Scaffold(
      appBar: AppBar(title: Text(widget.classroomName)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Button to navigate to Pass Token page
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TokenTransferPage(
                      ownUid:
                          GlobalStudentProfile.currentStudent?.uid ??
                          "", // Uses global UID
                      classroomId:
                          widget.classroomId, // Pass the current classroom ID
                    ),
                  ),
                );
              },

              child: const Text("Pass Token"),
            ),
            const SizedBox(height: 20),

            // Button to navigate to Add to Exception List page
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddExceptionPage(
                      classroomId: widget
                          .classroomId, // Replace with the actual classroom ID
                    ),
                  ),
                );
              },

              child: const Text("Add to Exception List"),
            ),
          ],
        ),
      ),
    );
  }
}
