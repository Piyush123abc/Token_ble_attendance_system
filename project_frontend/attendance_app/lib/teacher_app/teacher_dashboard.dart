// lib/teacher_app/teacher_dashboard.dart
import 'dart:convert';
import 'package:attendance_app/teacher_app/absence_proposals/teacher_pending_queue.dart';
import 'package:attendance_app/teacher_app/add_classroom_page.dart';
import 'package:attendance_app/teacher_app/attendance_session/AttendanceSessionPage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../global_variable/base_url.dart';
import '../global_variable/token_handles.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  Map<String, dynamic>? _profile;
  List<dynamic> _classrooms = [];
  bool _isLoading = true;
  String _statusMessage = "";
  Map<int, bool> _activeSessions = {};

  @override
  void initState() {
    super.initState();
    _fetchProfileAndClassrooms();
  }

  Future<void> _fetchProfileAndClassrooms() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "";
    });

    try {
      final profileResponse = await http.get(
        Uri.parse("${BaseUrl.value}/user/profile/"),
        headers: await TokenHandles.getAuthHeaders(),
      );

      if (profileResponse.statusCode == 200) {
        _profile = jsonDecode(profileResponse.body);
      } else {
        setState(() {
          _statusMessage =
              "❌ Failed to load profile: ${profileResponse.statusCode}";
        });
      }

      final classResponse = await http.get(
        Uri.parse("${BaseUrl.value}/user/teacher/classrooms/"),
        headers: await TokenHandles.getAuthHeaders(),
      );

      if (classResponse.statusCode == 200) {
        _classrooms = jsonDecode(classResponse.body);
        for (var classroom in _classrooms) {
          await _fetchSessionStatus(classroom['id']);
        }
      } else {
        setState(() {
          _statusMessage =
              "❌ Failed to load classrooms: ${classResponse.statusCode}";
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

  Future<void> _fetchSessionStatus(int classroomId) async {
    try {
      final response = await http.get(
        Uri.parse("${BaseUrl.value}/session/session/status/$classroomId/"),
        headers: await TokenHandles.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _activeSessions[classroomId] = data['active'] ?? false;
      } else {
        _activeSessions[classroomId] = false;
      }
    } catch (_) {
      _activeSessions[classroomId] = false;
    }
    setState(() {});
  }

  Future<void> _startOrEnterAttendance(int classroomId) async {
    bool? isActive = _activeSessions[classroomId];

    if (isActive == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AttendanceSessionPage(classroomId: classroomId),
        ),
      );
      return;
    }

    setState(() {
      _statusMessage = "⏳ Starting attendance...";
    });

    try {
      final response = await http.post(
        Uri.parse(
          "${BaseUrl.value}/session/teacher/classroom/$classroomId/start/",
        ),
        headers: await TokenHandles.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _statusMessage = "✅ ${data['message']}";
          _activeSessions[classroomId] = true;
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                AttendanceSessionPage(classroomId: classroomId),
          ),
        );
      } else {
        setState(() {
          _statusMessage =
              "❌ Failed to start session: ${response.statusCode}\n${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "❌ Error: $e";
      });
    }
  }

  void _goToAddClassroom() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddClassroomPage()),
    );

    if (result == true) {
      _fetchProfileAndClassrooms();
    }
  }

  void _goToPendingProposals() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PendingProposalsPage()),
    );
  }

  Widget _buildProfileCard() {
    if (_profile == null) return const SizedBox();
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "👤 ${_profile!['username'] ?? 'Teacher'}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text("UID: ${_profile!['uid'] ?? ''}"),
            Text("Department: ${_profile!['department'] ?? ''}"),
          ],
        ),
      ),
    );
  }

  Widget _buildClassroomCard(dynamic classroom) {
    final classroomId = classroom['id'];
    final bool isActive = _activeSessions[classroomId] ?? false;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
      child: ListTile(
        title: Text("${classroom['code']} - ${classroom['name']}"),
        subtitle: Text(
          "Created: ${classroom['created_at']?.substring(0, 10) ?? ''} | Active: ${isActive ? 'Yes' : 'No'}",
        ),
        trailing: ElevatedButton(
          onPressed: () => _startOrEnterAttendance(classroomId),
          style: ElevatedButton.styleFrom(
            backgroundColor: isActive ? Colors.green : null,
          ),
          child: Text(isActive ? "Enter Session" : "Start Attendance"),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Dashboard")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchProfileAndClassrooms,
              child: ListView(
                padding: const EdgeInsets.all(10),
                children: [
                  // ---------------- Pending Proposals Button ----------------
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: _goToPendingProposals,
                        icon: const Icon(Icons.pending_actions, size: 28),
                        label: const Text(
                          "Approval Queue",
                          style: TextStyle(fontSize: 20),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // ---------------- Profile Card ----------------
                  _buildProfileCard(),
                  const SizedBox(height: 10),
                  // ---------------- Classroom Cards ----------------
                  ..._classrooms.map((c) => _buildClassroomCard(c)).toList(),
                  if (_statusMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToAddClassroom,
        label: const Text("Add Classroom"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
