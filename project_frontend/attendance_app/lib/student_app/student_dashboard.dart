// lib/student/student_dashboard_page.dart
import 'dart:convert';
import 'package:attendance_app/global_variable/student_profile.dart';
import 'package:attendance_app/student_app/absence_proposal/absence_proposal_dashboard.dart';
import 'package:attendance_app/student_app/attendance_records/attendance_record_list.dart';
import 'package:attendance_app/student_app/attendance_session/attendance_session_dasboard.dart';
import 'package:attendance_app/student_app/classroom_list/classroom_list.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../global_variable/base_url.dart';
import '../global_variable/token_handles.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  Map<String, dynamic>? profile;
  List<dynamic> enrollments = [];
  Map<int, bool> sessionStatus = {}; // cache classroom session status
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  // --- HTTP GET with Authorization ---
  Future<http.Response> _getWithAuth(String url) async {
    final headers = await TokenHandles.getAuthHeaders();
    return http.get(Uri.parse(url), headers: headers);
  }

  // --- Fetch Profile and Enrollments ---
  Future<void> _fetchDashboardData() async {
    setState(() => isLoading = true);
    try {
      final profileRes = await _getWithAuth("${BaseUrl.value}/user/profile/");
      final enrollmentsRes = await _getWithAuth(
        "${BaseUrl.value}/user/student/enrollments/",
      );

      if (profileRes.statusCode == 200 && enrollmentsRes.statusCode == 200) {
        final parsedProfile = jsonDecode(profileRes.body);
        final parsedEnrollments = jsonDecode(enrollmentsRes.body);

        // Store globally
        GlobalStudentProfile.setProfile(
          StudentProfile.fromJwtPayload(parsedProfile),
        );

        setState(() {
          profile = parsedProfile;
          enrollments = parsedEnrollments;
        });

        // fetch session status for each classroom
        for (var enrollment in parsedEnrollments) {
          final classroomId = enrollment["id"];
          _fetchSessionStatus(classroomId);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to load data (Profile: ${profileRes.statusCode}, Enrollments: ${enrollmentsRes.statusCode})",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- Fetch Classroom Session Status ---
  Future<void> _fetchSessionStatus(int classroomId) async {
    try {
      final res = await _getWithAuth(
        "${BaseUrl.value}/session/session/status/$classroomId/",
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          sessionStatus[classroomId] = data["active"] ?? false;
        });
      }
    } catch (_) {}
  }

  // --- Placeholder Functions for Future Navigation ---
  void _onEnrollMorePressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StudentClassroomSearchPage(),
      ),
    );
  }

  void _onClassCardTapped(Map<String, dynamic> classroom) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceRecordPage(
          classroomId: classroom['id'],
          classroomName: classroom['name'],
          classroomCode: classroom['code'],
        ),
      ),
    );
  }

  void _onEnterSessionPressed(Map<String, dynamic> enrollment) {
    final classroomId = enrollment["id"];
    final classroomName = enrollment["name"] ?? "Class";
    final classroomCode = enrollment["code"] ?? "N/A";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceSessionPage(
          classroomId: classroomId,
          classroomName: classroomName,
          classroomCode: classroomCode,
        ),
      ),
    );
  }

  void _onAbsenceProposalPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AbsenceProposalPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDashboardData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDashboardData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Profile Section
                  if (profile != null)
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "👤 ${profile!['username'] ?? ''}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text("UID: ${profile!['uid'] ?? ''}"),
                            Text("Branch: ${profile!['branch'] ?? ''}"),
                          ],
                        ),
                      ),
                    ),

                  // --------------------
                  // After the Profile Section
                  // --------------------
                  const SizedBox(height: 7),

                  // Absence Proposal Button
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _onAbsenceProposalPressed,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              "📄 Submit Absence Proposal",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Enrollments Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "📚 Enrolled Classes",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _onEnrollMorePressed,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text("Enroll More"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (enrollments.isEmpty) const Text("No enrollments found."),
                  ...enrollments.map((enrollment) {
                    final classroomId = enrollment["id"];
                    final subject = enrollment["name"] ?? "Class";
                    final teacher = enrollment["teacher_name"] ?? "Unknown";
                    final isActive = sessionStatus[classroomId] == true;

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _onClassCardTapped(enrollment),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subject,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text("Instructor: $teacher"),
                              const SizedBox(height: 6),
                              Text(
                                "Attendance Session: ${isActive ? "Active" : "Inactive"}",
                                style: TextStyle(
                                  color: isActive ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: isActive
                                    ? () => _onEnterSessionPressed(enrollment)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isActive
                                      ? Colors.green
                                      : Colors.grey,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text("Enter Attendance Session"),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }
}
