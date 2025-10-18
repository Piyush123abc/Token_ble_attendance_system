// lib/global_variable/student_profile.dart

class StudentProfile {
  final int id;
  final String uid;
  final String username;
  final String branch;
  final String? authKey;

  StudentProfile({
    required this.id,
    required this.uid,
    required this.username,
    required this.branch,
    this.authKey,
  });

  // Factory to create from JWT payload
  factory StudentProfile.fromJwtPayload(Map<String, dynamic> payload) {
    return StudentProfile(
      id: payload['id'],
      uid: payload['uid'],
      username: payload['username'],
      branch: payload['branch'] ?? '',
      authKey: payload['auth_key'], // may be null
    );
  }
}

// Singleton/global holder
class GlobalStudentProfile {
  static StudentProfile? currentStudent;

  static void setProfile(StudentProfile profile) {
    currentStudent = profile;
  }

  static void clearProfile() {
    currentStudent = null;
  }
}
