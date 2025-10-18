// lib/student/classroom_detail_page.dart
import 'dart:convert';
import 'package:attendance_app/student_app/attendance_records/attendance_record_list.dart';
import 'package:attendance_app/student_app/attendance_session/attendance_session_dasboard.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../global_variable/base_url.dart';
import '../global_variable/token_handles.dart';

class ClassroomDetailPage extends StatefulWidget {
  final int classroomId;
  final String classroomName;
  final String classroomCode;

  const ClassroomDetailPage({
    super.key,
    required this.classroomId,
    required this.classroomName,
    required this.classroomCode,
  });

  @override
  State<ClassroomDetailPage> createState() => _ClassroomDetailPageState();
}

class _ClassroomDetailPageState extends State<ClassroomDetailPage> {
  bool _isLoading = true;
  bool _sessionActive = false;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _checkSessionStatus();
  }

  Future<void> _checkSessionStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    final url =
        "${BaseUrl.value}/student/classroom/${widget.classroomId}/session/";

    try {
      final headers = await TokenHandles.getAuthHeaders();
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _sessionActive = data['active'] ?? false;
          _isLoading = false;
        });
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _errorMessage = data['message'] ?? 'Failed to fetch session status';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Something went wrong: $e";
        _isLoading = false;
      });
    }
  }

  void _navigateToAttendanceRecords() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceRecordPage(
          classroomId: widget.classroomId, // pass the classroom ID
          classroomName: widget.classroomName, // pass the classroom name
          classroomCode: widget.classroomCode, // pass the classroom code
        ),
      ),
    );
  }

  void _navigateToAttendanceSession() {
    if (!_sessionActive) {
      // Show error if no active session
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No active attendance session")),
      );
      return;
    }

    // ✅ Navigate to AttendanceSessionPage if session is active
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceSessionPage(
          classroomId: widget.classroomId,
          classroomName: widget.classroomName,
          classroomCode: widget.classroomCode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.classroomCode} - ${widget.classroomName}"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage.isNotEmpty)
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _navigateToAttendanceRecords,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      "View Attendance Records",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _navigateToAttendanceSession,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                    ),
                    child: Text(
                      _sessionActive
                          ? "Join Attendance Session"
                          : "Session Not Active",
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
