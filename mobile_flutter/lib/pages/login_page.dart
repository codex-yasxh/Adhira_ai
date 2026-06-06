import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final AuthService _auth = AuthService();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _auth.signIn(email: _emailCtrl.text.trim(), password: _passCtrl.text);
      if (!mounted) return;
      // Navigate to main shell — app.dart listens to auth state and rebuilds
      Navigator.of(context).pushReplacementNamed('/home');
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF050510), Color(0xFF040713), Color(0xFF050510)],
              stops: <double>[0.0, 0.45, 1.0],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Logo
                      const Text(
                        'ADHIRA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your personal health assistant',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                      ),
                      const SizedBox(height: 36),

                      // Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xAA141420),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF2A2A3E)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            const Text(
                              'Start Your Journey',
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 18),
                            _field(
                              controller: _emailCtrl,
                              label: 'Email',
                              hint: 'you@example.com',
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                            ),
                            const SizedBox(height: 12),
                            _field(
                              controller: _passCtrl,
                              label: 'Password',
                              hint: '••••••••',
                              obscure: _obscure,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  size: 18,
                                  color: const Color(0xFF6B7280),
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                              validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _loading ? null : _signIn,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Register link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Text("Don't have an account? ", style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const RegisterPage()),
                            ),
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(color: Color.fromARGB(255, 255, 255, 255), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 13),
            suffixIcon: suffix,
            filled: true,
            fillColor: const Color(0xFF151B2A),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2A2A3E)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2A2A3E)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2563EB)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
          ),
        ),
      ],
    );
  }
}
