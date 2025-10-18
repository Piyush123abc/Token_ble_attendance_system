import 'dart:convert';
import 'package:attendance_app/teacher_app/attendance_session/GetExceptionList.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../global_variable/base_url.dart';
import '../../global_variable/token_handles.dart';
import 'ReceiveTokenPage.dart';

class AttendanceSessionPage extends StatelessWidget {
  final int classroomId;

  const AttendanceSessionPage({super.key, required this.classroomId});

  void _goToExceptionList(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExceptionListPage(classroomId: classroomId),
      ),
    );
  }

  void _goToReceiveToken(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiveTokenPage(classroomId: classroomId),
      ),
    );
  }

  Future<void> _endSession(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm End Session"),
        content: const Text("Are you sure you want to finalize attendance?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    Future<http.Response?> _tryRequest() async {
      try {
        return await http.post(
          Uri.parse(
            "${BaseUrl.value}/session/teacher/classroom/$classroomId/finalize/",
          ),
          headers: await TokenHandles.getAuthHeaders(),
        );
      } catch (e) {
        return null;
      }
    }

    // First attempt
    var response = await _tryRequest();

    // Retry once if unauthorized (token expired)
    if (response != null && response.statusCode == 401) {
      final refreshed = await TokenHandles.refreshAccessToken();
      if (refreshed) {
        response = await _tryRequest();
      }
    }

    if (response == null) {
      _showResultDialog(context, "❌ Network error");
      return;
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final summary = data["summary"];
      _showResultDialog(
        context,
        "✅ ${data["message"]}\n\n"
        "📊 Summary:\n"
        "- Total: ${summary["total_students"]}\n"
        "- Present: ${summary["present"]}\n"
        "- Absent: ${summary["absent"]}",
        success: true,
      );
    } else {
      _showResultDialog(context, "⚠️ Failed: ${response.body}");
    }
  }

  void _showResultDialog(
    BuildContext context,
    String message, {
    bool success = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Finalize Result"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              if (success) {
                Navigator.pop(context); // go back to parent page
              }
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Attendance Session")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "📝 Classroom ID: $classroomId",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => _goToExceptionList(context),
              icon: const Icon(Icons.error_outline),
              label: const Text("Exception List"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _goToReceiveToken(context),
              icon: const Icon(Icons.qr_code),
              label: const Text("Receive Token"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _endSession(context),
              icon: const Icon(Icons.stop_circle),
              label: const Text("End Session"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
