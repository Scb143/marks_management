class FacultyCredentials {
  final String facultyId;
  final String password;

  FacultyCredentials({required this.facultyId, required this.password});
}

class FacultyAuthResponse {
  final bool isSuccess;
  final String message;
  final Map<String, dynamic>? facultyData;

  FacultyAuthResponse({
    required this.isSuccess,
    required this.message,
    this.facultyData,
  });
}