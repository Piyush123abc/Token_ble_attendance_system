// lib/student/student_register_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart'; // ✅ For keypair
import '../../../global_variable/base_url.dart';

class StudentRegisterPage extends StatefulWidget {
  const StudentRegisterPage({super.key});

  @override
  State<StudentRegisterPage> createState() => _StudentRegisterPageState();
}

class _StudentRegisterPageState extends State<StudentRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _uidController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();

  bool _isLoading = false;

  // ✅ Generate a new keypair and return the public key (base64)
  Future<String> _generatePublicKey() async {
    final algorithm = Ed25519(); // ✅ modern, supported algorithm
    final keyPair = await algorithm.newKeyPair();

    // Extract and encode public key
    final publicKey = await keyPair.extractPublicKey();
    final rawBytes = publicKey.bytes;
    return base64Encode(rawBytes);
  }

  Future<void> _registerStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // ✅ Generate fingerprint public key
      final fingerprintKey = await _generatePublicKey();

      final url = Uri.parse("${BaseUrl.value}/user/register/student/");
      final body = jsonEncode({
        "username": _usernameController.text,
        "password": _passwordController.text,
        "uid": _uidController.text,
        "branch": _branchController.text,
        "fingerprint_key": fingerprintKey, // ✅ send key
      });

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Registration Successful 🎉"),
              content: Text(data.toString()),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // close dialog
                    Navigator.pop(context); // go back to StudentHomePage
                  },
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
      } else {
        final error = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $error")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Something went wrong: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Student Registration")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: "Username"),
                validator: (v) => v!.isEmpty ? "Enter username" : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Password"),
                obscureText: true,
                validator: (v) => v!.isEmpty ? "Enter password" : null,
              ),
              TextFormField(
                controller: _uidController,
                decoration: const InputDecoration(labelText: "UID"),
                validator: (v) => v!.isEmpty ? "Enter UID" : null,
              ),
              TextFormField(
                controller: _branchController,
                decoration: const InputDecoration(labelText: "Branch"),
                validator: (v) => v!.isEmpty ? "Enter branch" : null,
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _registerStudent,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text("Register"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
