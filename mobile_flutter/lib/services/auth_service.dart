import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final AuthResponse res = await _client.auth.signUp(
      email: email,
      password: password,
    );

    final User? user = res.user;
    if (user == null) throw Exception('Sign up failed. Please try again.');

    // Insert into public.users table
    await _client.from('users').insert({
      'id': user.id,
      'name': name,
      'email': email,
    });
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? getCurrentUser() {
    return _client.auth.currentUser;
  }
}
