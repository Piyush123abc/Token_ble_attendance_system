// lib/student/student_create_absence_proposal_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../global_variable/base_url.dart';
import '../../global_variable/token_handles.dart';

class CreateAbsenceProposalPage extends StatefulWidget {
  const CreateAbsenceProposalPage({super.key});

  @override
  State<CreateAbsenceProposalPage> createState() =>
      _CreateAbsenceProposalPageState();
}

class _CreateAbsenceProposalPageState extends State<CreateAbsenceProposalPage> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedReason;
  final TextEditingController _descriptionController = TextEditingController();

  DateTime? _startDateTime;
  DateTime? _endDateTime;

  File? _selectedFile;
  bool _isSubmitting = false;

  final List<String> _reasonOptions = ["MEDICAL", "EVENT", "ACADEMIC", "OTHER"];

  final ImagePicker _picker = ImagePicker();

  Future<http.MultipartRequest> _prepareRequest() async {
    final headers = await TokenHandles.getAuthHeaders();
    final uri = Uri.parse("${BaseUrl.value}user/absence-proposals/create/");
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(headers);

    request.fields['reason_type'] = _selectedReason!;
    request.fields['reason_description'] = _descriptionController.text.trim();
    request.fields['start_datetime'] = _startDateTime!.toIso8601String();
    request.fields['end_datetime'] = _endDateTime!.toIso8601String();

    if (_selectedFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('document', _selectedFile!.path),
      );
    }

    return request;
  }

  Future<void> _submitProposal() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDateTime == null || _endDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select start and end date/time.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final request = await _prepareRequest();
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Proposal created successfully!")),
        );
        Navigator.pop(context, true);
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed: ${data.toString()}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (image != null) {
      setState(() => _selectedFile = File(image.path));
    }
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    final dateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isStart) {
        _startDateTime = dateTime;
      } else {
        _endDateTime = dateTime;
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Absence Proposal")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedReason,
                decoration: const InputDecoration(
                  labelText: "Reason Type",
                  border: OutlineInputBorder(),
                ),
                items: _reasonOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedReason = val),
                validator: (value) =>
                    (value == null || value.isEmpty) ? "Required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Description",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.isEmpty) ? "Required" : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  _startDateTime == null
                      ? "Select Start Date & Time"
                      : "Start: ${_startDateTime.toString()}",
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDateTime(isStart: true),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text(
                  _endDateTime == null
                      ? "Select End Date & Time"
                      : "End: ${_endDateTime.toString()}",
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDateTime(isStart: false),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.image),
                label: Text(
                  _selectedFile == null
                      ? "Pick Image (Optional)"
                      : "Change Image",
                ),
                onPressed: _pickImage,
              ),
              if (_selectedFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "Selected: ${_selectedFile!.path.split('/').last}",
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitProposal,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Submit Proposal"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
