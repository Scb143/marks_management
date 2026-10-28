class UserCredentials {
  final String userId;
  final String password;

  UserCredentials({required this.userId, required this.password});

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'password': password,
    };
  }
}

class AuthResponse {
  final bool isSuccess;
  final String message;
  final String? token;
  final String? role; 

  AuthResponse({
    required this.isSuccess,
    required this.message,
    this.token,
    this.role,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      isSuccess: json['success'] ?? false,
      message: json['message'] ?? '',
      token: json['token'],
      role: json['role']?.toString().toLowerCase(),
    );
  }
}
