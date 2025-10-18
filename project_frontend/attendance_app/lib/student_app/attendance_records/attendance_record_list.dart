// lib/student/attendance_record_page.dart
import 'dart:convert';
import 'package:attendance_app/global_variable/base_url.dart';
import 'package:attendance_app/global_variable/token_handles.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AttendanceRecordPage extends StatefulWidget {
  final int classroomId;
  final String classroomName;
  final String classroomCode;

  const AttendanceRecordPage({
    super.key,
    required this.classroomId,
    required this.classroomName,
    required this.classroomCode,
  });

  @override
  State<AttendanceRecordPage> createState() => _AttendanceRecordPageState();
}

class _AttendanceRecordPageState extends State<AttendanceRecordPage> {
  bool _isLoading = true;
  String _errorMessage = "";
  List<dynamic> _records = [];

  int totalClasses = 0;
  int presentCount = 0;
  int absentCount = 0;
  int pendingCount = 0;

  double attendancePercentage = 0.0;
  double maxPotentialPercentage = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceRecords();
  }

  Future<void> _fetchAttendanceRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    final url =
        "${BaseUrl.value}/user/student/attendance/?classroom_id=${widget.classroomId}";

    try {
      final headers = await TokenHandles.getAuthHeaders();
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _records = data;

        // compute stats
        totalClasses = _records.length;
        presentCount = _records
            .where((r) => r['status'] == "PRESENT")
            .toList()
            .length;
        absentCount = _records
            .where((r) => r['status'] == "ABSENT")
            .toList()
            .length;
        pendingCount = _records
            .where((r) => r['status'] == "PENDING")
            .toList()
            .length;

        attendancePercentage = totalClasses > 0
            ? presentCount / totalClasses * 100
            : 0;
        maxPotentialPercentage = totalClasses > 0
            ? (presentCount + pendingCount) / totalClasses * 100
            : 0;

        setState(() {
          _isLoading = false;
        });
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _errorMessage =
              data['detail'] ??
              data['message'] ??
              'Failed to fetch attendance records';
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

  Widget _buildStatsCard() {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Attendance Stats",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _statTile(
                  "Total Classes",
                  totalClasses.toString(),
                  Colors.blue,
                ),
                _statTile("Present", presentCount.toString(), Colors.green),
                _statTile("Absent", absentCount.toString(), Colors.red),
                _statTile("Pending", pendingCount.toString(), Colors.orange),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Current Attendance: ${attendancePercentage.toStringAsFixed(1)}%",
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              "Attendance Including Pending: ${maxPotentialPercentage.toStringAsFixed(1)}%",
              style: const TextStyle(fontSize: 16, color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final date = record['date'] ?? '';
    final status = record['status'] ?? '';
    final timestamp = record['timestamp'] ?? '';

    Color statusColor;
    switch (status) {
      case "PRESENT":
        statusColor = Colors.green;
        break;
      case "ABSENT":
        statusColor = Colors.red;
        break;
      case "PENDING":
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor,
          child: Text(status[0]),
        ),
        title: Text(date),
        subtitle: Text("Timestamp: $timestamp"),
        trailing: Text(
          status,
          style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
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
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
            ? Center(
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            : _records.isEmpty
            ? const Center(child: Text("No attendance records found"))
            : ListView(
                children: [
                  _buildStatsCard(),
                  const SizedBox(height: 12),
                  ..._records.map((r) => _buildRecordCard(r)).toList(),
                ],
              ),
      ),
    );
  }
}
