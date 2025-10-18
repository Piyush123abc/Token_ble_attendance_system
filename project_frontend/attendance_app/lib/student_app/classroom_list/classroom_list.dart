import 'dart:convert';
import 'package:attendance_app/global_variable/base_url.dart';
import 'package:attendance_app/global_variable/token_handles.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class StudentClassroomSearchPage extends StatefulWidget {
  const StudentClassroomSearchPage({super.key});

  @override
  State<StudentClassroomSearchPage> createState() =>
      _StudentClassroomSearchPageState();
}

class _StudentClassroomSearchPageState
    extends State<StudentClassroomSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _classrooms = [];
  bool _isLoading = false;

  /// Fetch classrooms based on the code input
  Future<void> _searchClassrooms() async {
    final code = _searchController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final headers = await TokenHandles.getAuthHeaders();
      final response = await http.get(
        Uri.parse("${BaseUrl.value}/user/student/classrooms/?code=$code"),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _classrooms = data;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error fetching classrooms: ${response.statusCode}"),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to fetch classrooms: $e")));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Enroll the current student in the selected classroom
  Future<void> _enrollClassroom(int classroomId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enroll Confirmation"),
        content: const Text("Do you want to enroll in this classroom?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Enroll"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final headers = await TokenHandles.getAuthHeaders();
      headers['Content-Type'] = 'application/json';

      final response = await http.post(
        Uri.parse("${BaseUrl.value}/user/student/enroll/"),
        headers: headers,
        body: jsonEncode({"classroom": classroomId}),
      );

      if (response.statusCode == 201) {
        // Success
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Enrolled successfully!")));
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Enrollment failed: ${data['detail'] ?? data.toString()}",
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Enrollment request failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Classroom List")),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Search bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: "Search the classroom by code",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _searchClassrooms(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searchClassrooms,
                  child: const Text("Search"),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Loading indicator
            if (_isLoading) const LinearProgressIndicator(),

            // Classroom list
            Expanded(
              child: _classrooms.isEmpty
                  ? const Center(child: Text("No classrooms found"))
                  : ListView.builder(
                      itemCount: _classrooms.length,
                      itemBuilder: (context, index) {
                        final classroom = _classrooms[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            title: Text(
                              "${classroom['code']} - ${classroom['name']}",
                            ),
                            subtitle: Text(
                              "Created at: ${classroom['created_at'] ?? 'N/A'}",
                            ),
                            trailing: ElevatedButton(
                              onPressed: () =>
                                  _enrollClassroom(classroom['id']),
                              child: const Text("Enroll"),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
