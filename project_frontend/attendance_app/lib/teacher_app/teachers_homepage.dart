// import 'package:attendance_app/global_variable/base_url.dart';
import 'package:attendance_app/teacher_app/teac_regis/login/teacher_login_page.dart';
import 'package:attendance_app/teacher_app/teac_regis/login/teacher_register_page.dart';
import 'package:flutter/material.dart';
// so you can use BaseUrl.value anywhere

class TeachersHomePage extends StatelessWidget {
  const TeachersHomePage({super.key});

  void _goToRegister(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TeacherRegisterPage()),
    );
  }

  void _goToLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TeacherLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teacher's Home")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => _goToRegister(context),
              icon: const Icon(Icons.app_registration),
              label: const Text("Register"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _goToLogin(context),
              icon: const Icon(Icons.login),
              label: const Text("Login"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
