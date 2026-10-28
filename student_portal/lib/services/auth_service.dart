import 'package:supabase_flutter/supabase_flutter.dart' hide AuthResponse;
import '../main.dart';
import '../models/user_model.dart';
import 'package:bcrypt/bcrypt.dart';
//import 'package:flutter/foundation.dart';

class AuthService {
  Future<AuthResponse> login(UserCredentials credentials) async {
    try {
      final inputId = credentials.userId.trim();
      final inputPassword = credentials.password;

      // Query the users table in Supabase
      final List<dynamic> response = await supabase
          .from('users')
          .select('id, user_id, password_hash, role')
          .ilike('user_id', inputId)
          .limit(1);
      //debugPrint(
        //'Query response: $response',
      //); // If this is [], it is an RLS or User ID mismatch issue

      if (response.isEmpty) {
        //debugPrint('User not found for ID: $inputId');
        return AuthResponse(
          isSuccess: false,
          message: 'Invalid credentials. User not found.',
        );
      }

      final userData = response.first as Map<String, dynamic>;
      //debugPrint('Input Password: $inputPassword');
      //debugPrint('Stored Password/Hash: ${userData['password_hash']}');

      if (response.isEmpty) {
        return AuthResponse(
          isSuccess: false,
          message: 'Invalid credentials. User not found.',
        );
      }

     

      // Check password:
      // If storing plain text in DB:
      final storedHash = userData['password_hash'] as String;
      final bool isMatch = BCrypt.checkpw(inputPassword, storedHash);

      if (isMatch) {
        return AuthResponse(
          isSuccess: true,
          message: 'Login successful!',
          token: userData['id'].toString(),
          role: userData['role']?.toString().toLowerCase(),
        );
      } else {
        return AuthResponse(
          isSuccess: false,
          message: 'Invalid credentials. Incorrect password.',
        );
      }
    } on PostgrestException catch (e) {
      return AuthResponse(
        isSuccess: false,
        message: 'Database error: ${e.message}',
      );
    } catch (e) {
      return AuthResponse(
        isSuccess: false,
        message: 'Connection error: ${e.toString()}',
      );
    }
  }

  /// Step 1: Send a 6-digit OTP to the user's email
  Future<AuthResponse> sendPasswordResetOtp(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(
        email.trim(),
      );
      return AuthResponse(
        isSuccess: true,
        message: 'A 6-digit verification code has been sent to your email.',
      );
    } on AuthException catch (e) {
      return AuthResponse(isSuccess: false, message: e.message);
    } catch (e) {
      return AuthResponse(isSuccess: false, message: 'Failed to send OTP: ${e.toString()}');
    }
  }

  /// Step 2: Verify the 6-digit OTP
  Future<AuthResponse> verifyOtp(String email, String token) async {
    try {
      final response = await supabase.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.recovery,
      );

      if (response.session != null) {
        return AuthResponse(
          isSuccess: true,
          message: 'Code verified successfully.',
          token: response.session?.accessToken,
        );
      }
      return AuthResponse(isSuccess: false, message: 'Invalid or expired code.');
    } on AuthException catch (e) {
      return AuthResponse(isSuccess: false, message: e.message);
    } catch (e) {
      return AuthResponse(isSuccess: false, message: 'Verification failed: ${e.toString()}');
    }
  }

 /// Step 3: Update to the new password in BOTH Supabase Auth and public.users
Future<AuthResponse> updatePassword(String email, String newPassword) async {
  try {
    // 1. Update password in Supabase's internal auth system
    final authRes = await supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );

    if (authRes.user == null) {
      return AuthResponse(
        isSuccess: false,
        message: 'Could not update auth session. Please request OTP again.',
      );
    }

    // 2. Update password in your custom table (public.users)
    // NOTE: If you store plain text, assign directly.
    // If you use BCrypt in Flutter, hash it first: BCrypt.hashpw(newPassword, BCrypt.gensalt());
    await supabase
        .from('users')
        .update({'password_hash': newPassword})
        .ilike('email', email.trim());

    // 3. Sign out the recovery session so user can log in fresh
    await supabase.auth.signOut();

    return AuthResponse(
      isSuccess: true,
      message: 'Password updated successfully! Please log in.',
    );
  } on PostgrestException catch (e) {
    return AuthResponse(
      isSuccess: false,
      message: 'Database update error: ${e.message}',
    );
  } on AuthException catch (e) {
    return AuthResponse(isSuccess: false, message: e.message);
  } catch (e) {
    return AuthResponse(
      isSuccess: false,
      message: 'Failed to update password: ${e.toString()}',
    );
  }
}
}