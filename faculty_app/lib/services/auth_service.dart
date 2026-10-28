import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/user_model.dart';
import 'package:bcrypt/bcrypt.dart';
class FacultyAuthService {
  /// Portal Login: Verifies credentials directly against users & faculties tables
  Future<FacultyAuthResponse> login(FacultyCredentials credentials) async {
    try {
      final inputId = credentials.facultyId.trim();
      final inputPassword = credentials.password;

      // 1. Fetch user by user_id
      final List<dynamic> usersResponse = await supabase
          .from('users')
          .select('id, user_id, name, email, branch, role, password_hash')
          .ilike('user_id', inputId)
          .limit(1);

      if (usersResponse.isEmpty) {
        return FacultyAuthResponse(
          isSuccess: false,
          message: 'Invalid Faculty ID or account not found.',
        );
      }

      final userData = usersResponse.first as Map<String, dynamic>;

      // 2. Enforce Faculty role restriction
      final role = (userData['role'] ?? '').toString().toLowerCase();
      if (role != 'faculty' && role != 'admin') {
        return FacultyAuthResponse(
          isSuccess: false,
          message: 'Access denied. This portal is restricted to faculty members.',
        );
      }

      // 3. Verify password
      final storedHash = userData['password_hash'] as String;
      final bool isMatch = BCrypt.checkpw(inputPassword, storedHash);
      if (!isMatch) {
        return FacultyAuthResponse(
          isSuccess: false,
          message: 'Incorrect password. Please try again.',
        );
      }

      // 4. Optionally fetch additional faculty details
      Map<String, dynamic> combinedData = Map<String, dynamic>.from(userData);
      try {
        final List<dynamic> facultyDetails = await supabase
            .from('faculties')
            .select('designation, department, qualification')
            .ilike('faculty_id', inputId)
            .limit(1);

        if (facultyDetails.isNotEmpty) {
          combinedData.addAll(facultyDetails.first as Map<String, dynamic>);
        }
      } catch (_) {}

      return FacultyAuthResponse(
        isSuccess: true,
        message: 'Login successful!',
        facultyData: combinedData,
      );
    } on PostgrestException catch (e) {
      return FacultyAuthResponse(
        isSuccess: false,
        message: 'Database error: ${e.message}',
      );
    } catch (e) {
      return FacultyAuthResponse(
        isSuccess: false,
        message: 'Connection failed: ${e.toString()}',
      );
    }
  }

  /// Step 1: Send Password Reset OTP via Email
  Future<FacultyAuthResponse> sendPasswordResetOtp(String email) async {
    try {
      final List<dynamic> facultyCheck = await supabase
          .from('users')
          .select('email, role')
          .ilike('email', email.trim())
          .limit(1);

      if (facultyCheck.isEmpty) {
        return FacultyAuthResponse(
          isSuccess: false,
          message: 'No registered faculty account found with this email.',
        );
      }

      final role = (facultyCheck.first['role'] ?? '').toString().toLowerCase();
      if (role != 'faculty' && role != 'admin') {
        return FacultyAuthResponse(
          isSuccess: false,
          message: 'This email does not belong to a faculty account.',
        );
      }

      // Sends numeric OTP to the recipient email
      await supabase.auth.resetPasswordForEmail(email.trim());

      return FacultyAuthResponse(
        isSuccess: true,
        message: 'A verification code has been sent to your email.',
      );
    } on AuthException catch (e) {
      return FacultyAuthResponse(isSuccess: false, message: e.message);
    } catch (e) {
      return FacultyAuthResponse(
        isSuccess: false,
        message: 'Failed to send OTP: ${e.toString()}',
      );
    }
  }

  /// Step 2: Verify the received OTP token
  Future<FacultyAuthResponse> verifyOtp(String email, String token) async {
    try {
      final response = await supabase.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.recovery,
      );

      if (response.session != null) {
        return FacultyAuthResponse(
          isSuccess: true,
          message: 'OTP verified successfully.',
        );
      }
      return FacultyAuthResponse(
        isSuccess: false,
        message: 'Invalid or expired verification code.',
      );
    } on AuthException catch (e) {
      return FacultyAuthResponse(isSuccess: false, message: e.message);
    } catch (e) {
      return FacultyAuthResponse(
        isSuccess: false,
        message: 'Verification failed: ${e.toString()}',
      );
    }
  }

  /// Step 3: Set new password and sync across Supabase Auth & public.users table
  Future<FacultyAuthResponse> updatePassword(String email, String newPassword) async {
    try {
      // 1. Update Supabase Auth user password
      final authRes = await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (authRes.user == null) {
        return FacultyAuthResponse(
          isSuccess: false,
          message: 'Recovery session expired. Please request a new OTP.',
        );
      }

      // 2. Sync to public.users table
      await supabase
          .from('users')
          .update({'password_hash': newPassword})
          .ilike('email', email.trim());

      // 3. Clear temporary recovery session
      await supabase.auth.signOut();

      return FacultyAuthResponse(
        isSuccess: true,
        message: 'Password updated successfully! Please log in.',
      );
    } on PostgrestException catch (e) {
      return FacultyAuthResponse(
        isSuccess: false,
        message: 'Database update error: ${e.message}',
      );
    } on AuthException catch (e) {
      return FacultyAuthResponse(isSuccess: false, message: e.message);
    } catch (e) {
      return FacultyAuthResponse(
        isSuccess: false,
        message: 'Failed to update password: ${e.toString()}',
      );
    }
  }
}