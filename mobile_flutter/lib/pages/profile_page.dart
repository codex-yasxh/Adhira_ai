import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;

  String? _name;
  String? _email;
  DateTime? _createdAt;
  Map<String, dynamic>? _metrics;

  late final TextEditingController _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final userRow = await Supabase.instance.client
          .from('users')
          .select('name, email, created_at, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      final metricsRow = await Supabase.instance.client
          .from('health_metrics')
          .select('*')
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final String resolvedName =
          userRow?['name'] as String? ?? user.email?.split('@').first ?? 'User';

      setState(() {
        _name = resolvedName;
        _email = userRow?['email'] as String? ?? user.email ?? '';
        final String? rawDate = userRow?['created_at'] as String?;
        _createdAt = rawDate != null
            ? DateTime.tryParse(rawDate)
            : DateTime.tryParse(user.createdAt);
        _metrics = metricsRow;
        _loading = false;
        _nameCtrl.text = resolvedName;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) return;
    setState(() => _saving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('users')
          .update({'name': newName})
          .eq('id', user.id);

      setState(() {
        _name = newName;
        _editing = false;
        _saving = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save. Please try again.'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _cancelEdit() {
    _nameCtrl.text = _name ?? '';
    setState(() => _editing = false);
  }

  Future<void> _signOut() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  String get _initial => (_name != null && _name!.isNotEmpty)
      ? _name![0].toUpperCase()
      : (_email != null && _email!.isNotEmpty)
          ? _email![0].toUpperCase()
          : 'A';

  String _formatDate(DateTime dt) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: Color(0xFFD0D5DE)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: <Widget>[
          if (!_loading)
            _editing
                ? Row(
                    children: <Widget>[
                      TextButton(
                        onPressed: _saving ? null : _cancelEdit,
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF9CA3AF))),
                      ),
                      TextButton(
                        onPressed: _saving ? null : _saveProfile,
                        child: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF60A5FA)),
                              )
                            : const Text('Save', style: TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  )
                : IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF60A5FA)),
                    onPressed: () => setState(() => _editing = true),
                  ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF050510), Color(0xFF040713), Color(0xFF050510)],
            stops: <double>[0.0, 0.45, 1.0],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        children: <Widget>[
                          const SizedBox(height: 16),

                          // ── Avatar ──
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF2A2A3E), width: 2),
                              color: const Color(0xFF121725),
                            ),
                            child: Center(
                              child: Text(
                                _initial,
                                style: const TextStyle(
                                  color: Color(0xFF60A5FA),
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // ── Name — static or editable ──
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _editing
                                ? SizedBox(
                                    key: const ValueKey('edit'),
                                    width: 220,
                                    child: TextFormField(
                                      controller: _nameCtrl,
                                      autofocus: true,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        filled: true,
                                        fillColor: const Color(0xFF151B2A),
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
                                      ),
                                    ),
                                  )
                                : Text(
                                    key: const ValueKey('view'),
                                    _name ?? 'User',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 4),

                          // ── Email (never editable) ──
                          Text(
                            _email ?? '',
                            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                          ),
                          const SizedBox(height: 4),

                          // ── Member since ──
                          if (_createdAt != null)
                            Text(
                              'Member since ${_formatDate(_createdAt!)}',
                              style: const TextStyle(color: Color(0xFF4B5563), fontSize: 12),
                            ),

                          const SizedBox(height: 24),

                          // ── Health Profile ──
                          _SectionCard(
                            title: 'Health Profile',
                            child: _metrics == null
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'No metrics added yet.',
                                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                                    ),
                                  )
                                : Column(
                                    children: <Widget>[
                                      _MetricRow('Blood Pressure', _metrics!['blood_pressure']),
                                      _MetricRow('Heart Rate', _metrics!['heart_rate'], unit: 'bpm'),
                                      _MetricRow('Blood Sugar', _metrics!['blood_sugar'], unit: 'mg/dL'),
                                      _MetricRow('Weight', _metrics!['weight'], unit: 'kg'),
                                      _MetricRow('BMI', _metrics!['bmi']),
                                      _MetricRow('SpO2', _metrics!['spo2'], unit: '%'),
                                      _MetricRow('Sleep', _metrics!['sleep_hours'], unit: 'hrs'),
                                      _MetricRow('Steps', _metrics!['steps']),
                                      _MetricRow('Temperature', _metrics!['body_temp'], unit: '°F'),
                                      _MetricRow('Resp. Rate', _metrics!['resp_rate'], unit: 'br/min'),
                                    ].where((w) => (w as _MetricRow).value != null).toList(),
                                  ),
                          ),

                          const SizedBox(height: 16),

                          // ── Sign Out ──
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _signOut,
                              icon: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFFEF4444)),
                              label: const Text(
                                'Sign Out',
                                style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: Color(0x66EF4444)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

// ── Section Card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xAA141420),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFF2A2A3E)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ── Metric Row ────────────────────────────────────────────────────────────────

class _MetricRow extends StatelessWidget {
  const _MetricRow(this.label, this.value, {this.unit});

  final String label;
  final dynamic value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
          ),
          Text(
            unit != null ? '$value $unit' : '$value',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
