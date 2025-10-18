// lib/student/student_absence_proposal_page.dart
import 'dart:convert';
import 'package:attendance_app/student_app/absence_proposal/create_proposal.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../global_variable/base_url.dart';
import '../../global_variable/token_handles.dart';

class AbsenceProposalPage extends StatefulWidget {
  const AbsenceProposalPage({super.key});

  @override
  State<AbsenceProposalPage> createState() => _AbsenceProposalPageState();
}

class _AbsenceProposalPageState extends State<AbsenceProposalPage> {
  List<dynamic> proposals = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProposals();
  }

  Future<http.Response> _getWithAuth(String url) async {
    final headers = await TokenHandles.getAuthHeaders();
    return http.get(Uri.parse(url), headers: headers);
  }

  Future<void> _fetchProposals() async {
    setState(() => isLoading = true);
    try {
      final res = await _getWithAuth(
        "${BaseUrl.value}/user/absence-proposals/list/",
      );
      if (res.statusCode == 200) {
        setState(() {
          proposals = jsonDecode(res.body);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load proposals: ${res.statusCode}"),
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

  void _onCreateProposalPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateAbsenceProposalPage(),
      ),
    );
  }

  Widget _buildProposalCard(Map<String, dynamic> proposal) {
    final status = proposal['status'] ?? 'PENDING';
    final reason = proposal['reason_type'] ?? 'Unknown';
    final desc = proposal['reason_description'] ?? '';
    final start = proposal['start_datetime'] ?? '';
    final end = proposal['end_datetime'] ?? '';
    final documentUrl = proposal['document'];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Reason: $reason",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text("Description: $desc"),
            const SizedBox(height: 6),
            Text("Start: $start"),
            Text("End: $end"),
            const SizedBox(height: 6),
            Text(
              "Status: $status",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: status == "APPROVED"
                    ? Colors.green
                    : status == "REJECTED"
                    ? Colors.red
                    : Colors.orange,
              ),
            ),
            if (documentUrl != null)
              TextButton.icon(
                onPressed: () {
                  // TODO: Open document in browser / PDF viewer
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("View Document"),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Absence Proposals"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchProposals,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchProposals,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // -----------------------------
                  // Create Proposal Card
                  // -----------------------------
                  Card(
                    color: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.note_add, color: Colors.white),
                      title: const Text(
                        "Create Absence Proposal",
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: _onCreateProposalPressed,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // -----------------------------
                  // List of Existing Proposals
                  // -----------------------------
                  if (proposals.isEmpty)
                    const Center(child: Text("No proposals found."))
                  else
                    ...proposals.map((p) => _buildProposalCard(p)).toList(),
                ],
              ),
            ),
    );
  }
}
