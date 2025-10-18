// lib/teacher_app/pending_proposal_detail_page.dart
import 'dart:io';
import 'package:attendance_app/global_variable/base_url.dart';
import 'package:attendance_app/global_variable/token_handles.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:photo_view/photo_view.dart';

class PendingProposalDetailPage extends StatefulWidget {
  final Map<String, dynamic> proposal;

  const PendingProposalDetailPage({super.key, required this.proposal});

  @override
  State<PendingProposalDetailPage> createState() =>
      _PendingProposalDetailPageState();
}

class _PendingProposalDetailPageState extends State<PendingProposalDetailPage> {
  bool _isProcessing = false;
  File? _previewFile;
  String? _previewError;
  bool _isLoadingPreview = false;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  String formatDateTime(String datetimeStr) {
    try {
      final dt = DateTime.parse(datetimeStr).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return datetimeStr;
    }
  }

  Future<File?> _downloadFile(String url) async {
    try {
      debugPrint("🔹 Downloading file from: $url");
      final response = await http.get(Uri.parse(url));

      debugPrint("🔹 Response code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final fileName = url.split('/').last;
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        debugPrint("✅ File saved at: ${file.path}");
        return file;
      } else {
        debugPrint("❌ File download failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ File download exception: $e");
      setState(() => _previewError = e.toString());
    }
    return null;
  }

  Future<void> _loadPreview() async {
    final url = widget.proposal['document_url'];
    if (url == null || url.isEmpty) return;

    setState(() {
      _isLoadingPreview = true;
      _previewError = null;
    });

    final file = await _downloadFile(url);
    if (file != null && mounted) {
      setState(() => _previewFile = file);
    } else {
      setState(() => _previewError = "Failed to load file");
    }

    setState(() => _isLoadingPreview = false);
  }

  Future<void> _updateProposalStatus(String status) async {
    setState(() => _isProcessing = true);

    try {
      final url =
          "${BaseUrl.value}user/teacher/absence-proposal/${widget.proposal['id']}/update/";
      debugPrint("🔹 PATCH => $url with status=$status");

      final response = await http.patch(
        Uri.parse(url),
        headers: await TokenHandles.getAuthHeaders(),
        body: {'status': status},
      );

      debugPrint("🔹 Response: ${response.statusCode} => ${response.body}");

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Proposal $status successfully")),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final proposal = widget.proposal;
    final student = proposal['student'] ?? {};
    final docUrl = proposal['document_url'];

    return Scaffold(
      appBar: AppBar(title: const Text("Proposal Details")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------- Header -------------------
            Center(
              child: Column(
                children: [
                  const Icon(Icons.assignment, size: 60, color: Colors.blue),
                  Text(
                    "Absence Proposal Review",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ------------------- Student Info -------------------
            _infoCard("👨‍🎓 Student Details", [
              _infoRow("Name", student['username'] ?? "-"),
              _infoRow("UID", student['uid'] ?? "-"),
              _infoRow("Branch", student['branch'] ?? "-"),
            ]),
            const SizedBox(height: 16),

            // ------------------- Proposal Info -------------------
            _infoCard("📋 Proposal Information", [
              _infoRow("Reason", proposal['reason_type'] ?? "-"),
              _infoRow("Description", proposal['reason_description'] ?? "-"),
              _infoRow(
                "Start",
                formatDateTime(proposal['start_datetime'] ?? "-"),
              ),
              _infoRow("End", formatDateTime(proposal['end_datetime'] ?? "-")),
              _infoRow("Status", proposal['status'] ?? "-"),
            ]),

            const SizedBox(height: 20),

            // ------------------- Document Preview -------------------
            if (docUrl != null && docUrl.isNotEmpty) ...[
              const Text(
                "📎 Attached Document",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              if (_isLoadingPreview)
                const Center(child: CircularProgressIndicator()),

              if (_previewError != null)
                Text(
                  "❌ Error loading file: $_previewError",
                  style: const TextStyle(color: Colors.redAccent),
                ),

              if (_previewFile != null) _buildDocumentPreview(docUrl),

              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: () => _openDocument(docUrl),
                icon: const Icon(Icons.open_in_new),
                label: const Text("Open Full Document"),
              ),
            ],

            const SizedBox(height: 30),

            // ------------------- Approve/Reject Buttons -------------------
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () => _updateProposalStatus("REJECTED"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Reject",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () => _updateProposalStatus("APPROVED"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Approve",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String title, List<Widget> children) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              key,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentPreview(String url) {
    final isPdf = url.toLowerCase().endsWith('.pdf');

    return Container(
      height: 250,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: isPdf
          ? PDFView(filePath: _previewFile!.path)
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _previewFile!,
                fit: BoxFit.contain,
                errorBuilder: (_, e, __) =>
                    Center(child: Text("⚠️ Image Load Error: $e")),
              ),
            ),
    );
  }

  void _openDocument(String url) async {
    final file = await _downloadFile(url);
    if (file == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to load document")));
      return;
    }

    final isPdf = url.toLowerCase().endsWith('.pdf');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            isPdf ? PDFViewerPage(file: file) : ImageViewerPage(file: file),
      ),
    );
  }
}

// -------------------- PDF Viewer --------------------
class PDFViewerPage extends StatelessWidget {
  final File file;
  const PDFViewerPage({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PDF Document")),
      body: PDFView(filePath: file.path),
    );
  }
}

// -------------------- Image Viewer --------------------
class ImageViewerPage extends StatelessWidget {
  final File file;
  const ImageViewerPage({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Image Document")),
      body: PhotoView(imageProvider: FileImage(file)),
    );
  }
}
