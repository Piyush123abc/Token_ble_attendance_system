import 'dart:convert';
import 'package:attendance_app/global_variable/base_url.dart';
import 'package:attendance_app/global_variable/token_handles.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// import '../global_variable/base_url.dart';
// import '../global_variable/token_handles.dart';

class ExceptionListPage extends StatefulWidget {
  final int classroomId;
  const ExceptionListPage({super.key, required this.classroomId});

  @override
  State<ExceptionListPage> createState() => _ExceptionListPageState();
}

class _ExceptionListPageState extends State<ExceptionListPage> {
  List<Map<String, dynamic>> exceptionList = [];
  final Set<String> markedPresent = <String>{};
  bool loading = true;
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    fetchExceptionList();
  }

  // --- Auth helpers that use TokenHandles and auto-refresh on 401 ---
  Future<http.Response?> _authorizedGet(Uri url) async {
    var res = await http.get(url, headers: await TokenHandles.getAuthHeaders());
    if (res.statusCode == 401 && await TokenHandles.refreshAccessToken()) {
      res = await http.get(url, headers: await TokenHandles.getAuthHeaders());
    }
    return res;
  }

  Future<http.Response?> _authorizedPost(Uri url, Object body) async {
    var headers = {
      ...await TokenHandles.getAuthHeaders(),
      "Content-Type": "application/json",
    };
    var res = await http.post(url, headers: headers, body: jsonEncode(body));
    if (res.statusCode == 401 && await TokenHandles.refreshAccessToken()) {
      headers = {
        ...await TokenHandles.getAuthHeaders(),
        "Content-Type": "application/json",
      };
      res = await http.post(url, headers: headers, body: jsonEncode(body));
    }
    return res;
  }

  Future<void> fetchExceptionList() async {
    setState(() {
      loading = true;
    });

    final url = Uri.parse(
      "${BaseUrl.value}/session/teacher/classroom/${widget.classroomId}/exceptions/",
    );

    try {
      final res = await _authorizedGet(url);
      if (res == null) {
        _showError("No response from server.");
        setState(() => loading = false);
        return;
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list =
            (data["exception_list"] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            <Map<String, dynamic>>[];
        setState(() {
          exceptionList = List<Map<String, dynamic>>.from(list);
          loading = false;
        });
      } else {
        String msg = "Failed to load exception list";
        try {
          final d = jsonDecode(res.body);
          msg = d["error"] ?? d["message"] ?? msg;
        } catch (_) {}
        _showError(msg);
        setState(() => loading = false);
      }
    } catch (e) {
      setState(() => loading = false);
      _showError("Network error: $e");
    }
  }

  Future<void> submitPresent() async {
    if (markedPresent.isEmpty) {
      _showError("No students marked present.");
      return;
    }

    setState(() => submitting = true);

    final url = Uri.parse(
      "${BaseUrl.value}/session/teacher/classroom/${widget.classroomId}/mark-present/",
    );

    try {
      final res = await _authorizedPost(url, {
        "present_uids": markedPresent.toList(),
      });
      setState(() => submitting = false);

      if (res == null) {
        _showError("No response from server.");
        return;
      }

      if (res.statusCode == 200) {
        String msg = "Students marked present.";
        try {
          final d = jsonDecode(res.body);
          msg = d["message"] ?? msg;
        } catch (_) {}
        _showSuccess(msg);
      } else {
        String msg = "Failed to mark present.";
        try {
          final d = jsonDecode(res.body);
          msg = d["error"] ?? d["message"] ?? msg;
        } catch (_) {}
        _showError(msg);
      }
    } catch (e) {
      setState(() => submitting = false);
      _showError("Network error: $e");
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("❌ Error"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("✅ Success"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(
                context,
                true,
              ); // pop page and return "true" to parent
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _studentCard(Map<String, dynamic> student) {
    final uid = student["uid"]?.toString() ?? "";
    final username = student["username"]?.toString() ?? "Unknown";
    final isMarked = markedPresent.contains(uid);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Placeholder image (implement real image later)
            const CircleAvatar(
              radius: 30,
              backgroundImage: AssetImage("assets/placeholder.png"),
            ),
            const SizedBox(height: 8),
            Text(
              username,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text("UID: $uid"),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      markedPresent.add(uid);
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMarked ? Colors.green : Colors.grey,
                  ),
                  child: const Text("Present"),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      markedPresent.remove(uid);
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !isMarked ? Colors.red : Colors.grey,
                  ),
                  child: const Text("Absent"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text("Exceptions")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Exception List")),
      body: exceptionList.isEmpty
          ? const Center(child: Text("No students in exception list"))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: exceptionList.length,
              itemBuilder: (context, index) {
                final student = exceptionList[index];
                return _studentCard(student);
              },
            ),
      bottomNavigationBar: exceptionList.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton(
                onPressed: submitting ? null : submitPresent,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("Submit Present"),
              ),
            )
          : null,
    );
  }
}
