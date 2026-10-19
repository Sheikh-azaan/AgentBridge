import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  String? get currentUserId => _supabase.auth.currentUser?.id;
  String? get currentUserEmail => _supabase.auth.currentUser?.email;
  bool get isAuthenticated => _supabase.auth.currentUser != null;
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } catch (e) {
      debugPrint('[AuthService] signIn error: $e');
      rethrow;
    }
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: name != null && name.isNotEmpty ? {'name': name} : null,
      );

      final user = response.user;
      if (user != null) {
        try {
          await _supabase.from('profiles').upsert({
            'id': user.id,
            'name': name ?? 'Agent Owner',
            'email': email.trim(),
            'role': 'Owner',
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (profileError) {
          debugPrint('[AuthService] Profile creation error: $profileError');
        }
      }

      return response;
    } catch (e) {
      debugPrint('[AuthService] signUp error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('[AuthService] signOut error: $e');
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email.trim());
    } catch (e) {
      debugPrint('[AuthService] resetPassword error: $e');
      rethrow;
    }
  }

  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      return await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      debugPrint('[AuthService] updatePassword error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getProfile([String? userId]) async {
    final uid = userId ?? currentUserId;
    if (uid == null) return null;

    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint('[AuthService] getProfile error: $e');
      return null;
    }
  }

  Future<void> updateProfile({
    required String name,
    String? phone,
    String? role,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('No authenticated user');

    try {
      final updates = <String, dynamic>{
        'id': uid,
        'name': name,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (phone != null) updates['phone'] = phone;
      if (role != null) updates['role'] = role;

      await _supabase.from('profiles').upsert(updates);
    } catch (e) {
      debugPrint('[AuthService] updateProfile error: $e');
      rethrow;
    }
  }
}
