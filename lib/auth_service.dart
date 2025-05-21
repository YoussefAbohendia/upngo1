import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'dart:convert';

class AuthService {
  static const String _sessionKey = 'auth_session';
  static const String _userKey = 'auth_user';
  static const String _rememberMeKey = 'auth_remember_me';

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionString = prefs.getString(_sessionKey);

    // If we have a session stored
    if (sessionString != null) {
      try {
        // Check if the session is still valid with Supabase
        final user = supabase.auth.currentUser;
        return user != null;
      } catch (e) {
        // If error, clear stored session and return false
        await logout();
        return false;
      }
    }
    return false;
  }

  // Login with email and password
  static Future<AuthResponse> login(String email, String password, {bool rememberMe = true}) async {
    final response = await supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    if (response.session != null) {
      // Store session and user data
      await _saveSession(response.session!, response.user!, rememberMe);
    }

    return response;
  }

  // Register with email and password
  static Future<AuthResponse> register(String email, String password) async {
    final response = await supabase.auth.signUp(
      email: email.trim(),
      password: password,
    );

    if (response.session != null) {
      // Store session and user data
      await _saveSession(response.session!, response.user!, true);
    }

    return response;
  }

  // Create user profile in database
  static Future<void> createUserProfile(String userId, String email) async {
    try {
      await supabase.from('profiles').insert({
        'id': userId,
        'email': email,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error creating user profile: $e');
      // Continue even if profile creation fails - can be handled later
    }
  }

  // Logout
  static Future<void> logout() async {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      // Continue with local logout even if API call fails
    }

    // Clear stored session data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_userKey);
    // We keep the remember me preference
  }

  // Save session to shared preferences
  static Future<void> _saveSession(Session session, User user, bool rememberMe) async {
    final prefs = await SharedPreferences.getInstance();

    if (rememberMe) {
      await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
      await prefs.setString(_userKey, user.email ?? '');
    }

    await prefs.setBool(_rememberMeKey, rememberMe);
  }

  // Get current user email
  static Future<String?> getCurrentUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userKey);
  }

  // Get current user ID
  static Future<String?> getCurrentUserId() async {
    final user = supabase.auth.currentUser;
    return user?.id;
  }

  // Check if "remember me" is enabled
  static Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? true;
  }

  // Password reset
  static Future<void> resetPassword(String email) async {
    await supabase.auth.resetPasswordForEmail(
      email.trim(),
    );
  }

  // Update user profile
  static Future<void> updateUserProfile({
    required String userId,
    String? displayName,
    String? avatarUrl,
    Map<String, dynamic>? preferences,
  }) async {
    final updates = {
      'updated_at': DateTime.now().toIso8601String(),
      if (displayName != null) 'display_name': displayName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (preferences != null) 'preferences': preferences,
    };

    await supabase.from('profiles').update(updates).eq('id', userId);
  }

  // Get user profile
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final response = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    return response;
  }
}