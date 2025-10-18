import 'package:attendance_app/global_variable/base_url.dart';
import 'package:attendance_app/global_variable/token_handles.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddExceptionPage extends StatefulWidget {
  final int classroomId; // Pass classroom ID when opening this page
  const AddExceptionPage({super.key, required this.classroomId});

  @override
  State<AddExceptionPage> createState() => _AddExceptionPageState();
}

class _AddExceptionPageState extends State<AddExceptionPage> {
  final TextEditingController _uidController = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    final uid = _uidController.text.trim();
    if (uid.isEmpty) {
      _showDialog("Error", "Please enter a UID.");
      return;
    }

    setState(() => _loading = true);

    try {
      // Get headers with JWT
      final headers = await TokenHandles.getAuthHeaders();
      if (headers.isEmpty) {
        _showDialog("Error", "Authentication failed. Please login again.");
        setState(() => _loading = false);
        return;
      }

      // Build URL
      final url = Uri.parse(
        "${BaseUrl.value}/session/student/classroom/${widget.classroomId}/exception/",
      );

      // Send POST request with UID in body
      final response = await http.post(
        url,
        headers: {...headers, "Content-Type": "application/json"},
        body: jsonEncode({"uid": uid}), // send UID to backend
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _showDialog("Success", data['message'] ?? "Added to exception list.");
        _uidController.clear();
      } else {
        _showDialog("Error", data['error'] ?? "Something went wrong.");
      }
    } catch (e) {
      _showDialog("Error", e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add to Exception List")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _uidController,
              decoration: const InputDecoration(
                labelText: "Enter UID",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _submit,
                    child: const Text("Add to Exception List"),
                  ),
          ],
        ),
      ),
    );
  }
}
