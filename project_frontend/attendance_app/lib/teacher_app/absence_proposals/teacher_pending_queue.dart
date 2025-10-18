// lib/teacher_app/pending_proposals_page.dart
import 'dart:convert';
import 'package:attendance_app/global_variable/base_url.dart';
import 'package:attendance_app/global_variable/token_handles.dart';
import 'package:attendance_app/teacher_app/absence_proposals/proposal_detial.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PendingProposalsPage extends StatefulWidget {
  const PendingProposalsPage({super.key});

  @override
  State<PendingProposalsPage> createState() => _PendingProposalsPageState();
}

class _PendingProposalsPageState extends State<PendingProposalsPage> {
  bool _isLoading = true;
  String _statusMessage = "";
  List<dynamic> _pendingProposals = [];

  @override
  void initState() {
    super.initState();
    _fetchPendingProposals();
  }

  Future<void> _fetchPendingProposals() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "";
    });

    try {
      final response = await http.get(
        Uri.parse("${BaseUrl.value}user/teacher/absence-proposals/pending/"),
        headers: await TokenHandles.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _pendingProposals = data;
        });
      } else {
        setState(() {
          _statusMessage = "❌ Failed to load: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "❌ Error: $e";
      });
    }

    setState(() => _isLoading = false);
  }

  Widget _buildProposalCard(dynamic proposal) {
    final student = proposal['student'] ?? {};
    final start = proposal['start_datetime'] ?? '';
    final end = proposal['end_datetime'] ?? '';
    final reason = proposal['reason_type'] ?? '';
    final uid = student['uid'] ?? '';
    final name = student['username'] ?? '';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: ListTile(
        title: Text("$name ($uid)"),
        subtitle: Text("Reason: $reason\nTime: $start → $end"),
        isThreeLine: true,
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () async {
          // Navigate to detailed proposal page with proposal object
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  PendingProposalDetailPage(proposal: proposal),
            ),
          );

          // ✅ Always reload the parent page after returning
          _fetchPendingProposals();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pending Proposals")),
      body: RefreshIndicator(
        onRefresh: _fetchPendingProposals,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _pendingProposals.isEmpty
            ? Center(
                child: Text(
                  _statusMessage.isEmpty
                      ? "✅ No pending proposals"
                      : _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: _pendingProposals.length,
                itemBuilder: (context, index) =>
                    _buildProposalCard(_pendingProposals[index]),
              ),
      ),
    );
  }
}
