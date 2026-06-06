import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/network/api_client.dart';
import '../services/android_sms_sender.dart';
import '../services/sms_intent_fallback_sender.dart';
import '../services/sos_sender.dart';

class SosPage extends StatefulWidget {
  const SosPage({super.key});

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  // ignore: unused_field
  final ApiClient _apiClient = ApiClient();

  bool _sendingSos = false;
  String _sosStatus = '';
  Timer? _sosStatusTimer;
  int _sosStatusIndex = 0;
  List<_EmergencyContact> _contacts = [];

  static const List<String> _sosMessages = [
    'Checking emergency contacts...',
    'Preparing SOS message...',
    'Getting your location...',
    'Contacting your trusted people...',
    'Sending emergency alerts...',
    'ADHIRA is reaching out to people you trust...',
    'Almost done...',
    'Almost done...',
    'Almost done...',
  ];

  void _startStatusRotation() {
    _sosStatusIndex = 0;
    _setStatus(_sosMessages[0]);
    _sosStatusTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (!mounted) return;
      _sosStatusIndex = (_sosStatusIndex + 1) % _sosMessages.length;
      _setStatus(_sosMessages[_sosStatusIndex]);
    });
  }

  void _stopStatusRotation() {
    _sosStatusTimer?.cancel();
    _sosStatusTimer = null;
    if (mounted) setState(() => _sosStatus = '');
  }

  @override
  void dispose() {
    _sosStatusTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  // ─── Contacts ──────────────────────────────────────────────────────────────

  Future<void> _loadContacts() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _contacts = []);
        return;
      }
      final rows = await _supabase
          .from('emergency_contacts')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      final loaded = rows
          .whereType<Map<String, dynamic>>()
          .map(_EmergencyContact.fromRow)
          .toList();

      debugPrint('[SOS] Contacts loaded — ${loaded.length}');
      if (mounted) setState(() => _contacts = loaded);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not load emergency contacts', isError: true);
    }
  }


  Future<String?> _fetchLocationUrl() async {
    try {
      debugPrint('[SOS] Checking location permission');
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('[SOS] Location services enabled: $serviceEnabled');
      if (!serviceEnabled) {
        debugPrint('[SOS] Location services OFF — skipping');
        return null;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      debugPrint('[SOS] Location permission status: $perm');

      if (perm == LocationPermission.denied) {
        debugPrint('[SOS] Requesting location permission');
        perm = await Geolocator.requestPermission();
        debugPrint('[SOS] Location permission after request: $perm');
      }

      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        debugPrint('[SOS] Location permission denied — skipping');
        return null;
      }

      debugPrint('[SOS] Location permission granted');
      debugPrint('[SOS] Requesting current position');

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      debugPrint('[SOS] Current position received');
      debugPrint('[SOS] Latitude: ${pos.latitude}');
      debugPrint('[SOS] Longitude: ${pos.longitude}');
      return 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
    } catch (e, stack) {
      debugPrint('[SOS] Location exception: $e');
      debugPrint('[SOS] Location stacktrace: $stack');
      return null;
    }
  }

  // ─── Permissions ───────────────────────────────────────────────────────────

  Future<bool> _requestSmsPermission() async {
    final status = await Permission.sms.request();
    if (status.isGranted) return true;
    if (!mounted) return false;
    if (status.isPermanentlyDenied) {
      _showSnack(
        'SMS permission permanently denied. Enable it in App Settings.',
        isError: true,
        action: SnackBarAction(
          label: 'Settings',
          onPressed: openAppSettings,
          textColor: Colors.white,
        ),
      );
    } else {
      _showSnack('SMS permission denied.', isError: true);
    }
    return false;
  }

  // ─── Countdown ─────────────────────────────────────────────────────────────

  Future<bool> _showCountdown() async {
    final completer = Completer<bool>();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CountdownDialog(
        onComplete: () {
          if (!completer.isCompleted) completer.complete(true);
        },
        onCancel: () {
          if (!completer.isCompleted) completer.complete(false);
        },
      ),
    );

    final result = await completer.future;
    debugPrint('[SOS] Countdown ${result ? 'completed' : 'cancelled'}');
    return result;
  }

  // ─── Main SOS handler ──────────────────────────────────────────────────────

  void _setStatus(String msg) {
    if (mounted) setState(() => _sosStatus = msg);
  }

  Future<void> _handleSosTap() async {
    if (_sendingSos) return;

    await _loadContacts();
    if (!mounted) return;

    if (_contacts.isEmpty) {
      _showSnack('Please add emergency contacts first.', isError: false);
      return;
    }

    final confirmed = await _showConfirmation();
    if (!confirmed || !mounted) return;

    debugPrint('[SOS] Countdown started');
    final proceed = await _showCountdown();
    if (!proceed || !mounted) return;

    setState(() => _sendingSos = true);
    _startStatusRotation();

    // Fetch name from public.users (same source as profile page)
    final user = _supabase.auth.currentUser;
    String userName = 'ADHIRA User';
    if (user != null) {
      try {
        final row = await _supabase
            .from('users')
            .select('name')
            .eq('id', user.id)
            .maybeSingle();
        final dbName = (row?['name'] as String?)?.trim() ?? '';
        if (dbName.isNotEmpty) {
          userName = dbName;
        } else {
          // fallback to email prefix
          final email = user.email ?? '';
          if (email.isNotEmpty) userName = email.split('@').first;
        }
      } catch (_) {
        // non-critical — keep default
      }
    }
    debugPrint('[SOS] User name resolved: $userName');

    // ── Step 1: SMS permission first ──────────────────────────────────────
    debugPrint('[SOS] Requesting SMS permission');
    final smsGranted = await _requestSmsPermission();
    debugPrint('[SOS] SMS permission ${smsGranted ? 'granted' : 'denied'}');

    // ── Step 2: Location second (only after SMS dialog is gone) ───────────
    debugPrint('[SOS] Requesting location');
    final locationUrl = await _fetchLocationUrl();
    debugPrint('[SOS] Location ${locationUrl != null ? 'acquired: $locationUrl' : 'unavailable'}');

    final locationLine = locationUrl != null
        ? 'Location:\n$locationUrl'
        : 'Location: unavailable';

    final message = '🚨 Help !!\n\n'
        '$userName may need immediate help.\n\n'
        '$locationLine\n\n'
        'Please contact immediately.';

    final phones = _contacts.map((c) => c.phone).toList();
    debugPrint('[SOS] SMS sending started — ${phones.length} contact(s)');

    // ── Step 3: Choose sender ─────────────────────────────────────────────
    SosSender sender;

    if (!smsGranted) {
      debugPrint('[SOS] SMS permission denied — using fallback');
      sender = SmsIntentFallbackSender();
    } else {
      debugPrint('[SOS] Checking SIM availability');
      final simReady = await AndroidSmsSender.hasSim();
      debugPrint('[SOS] SIM ready: $simReady');
      if (!simReady) {
        debugPrint('[SOS] No SIM detected — using fallback');
        sender = SmsIntentFallbackSender();
      } else {
        debugPrint('[SOS] Calling AndroidSmsSender');
        sender = AndroidSmsSender();
      }
    }

    SosSendResult sendResult;
    try {
      sendResult = await sender.send(phones: phones, message: message);
    } catch (e) {
      debugPrint('[SOS] Sender threw — $e — using fallback');
      sendResult =
          await SmsIntentFallbackSender().send(phones: phones, message: message);
    }

    if (!mounted) return;
    _stopStatusRotation();
    setState(() => _sendingSos = false);

    _logSosEvent(
      locationUrl: locationUrl,
      successCount: sendResult.successCount,
      failureCount: sendResult.failureCount,
    );

    if (sendResult.usedFallback) {
      _showSnack(
        '📱 SMS app opened — please tap Send to alert your contacts.',
        isError: false,
        duration: const Duration(seconds: 5),
      );
    } else {
      _showResultDialog(sendResult);
    }
  }

  // ─── Supabase event log ────────────────────────────────────────────────────

  void _logSosEvent({
    String? locationUrl,
    required int successCount,
    required int failureCount,
  }) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final parts = locationUrl
        ?.replaceFirst('https://maps.google.com/?q=', '')
        .split(',');
    final lat =
        parts != null && parts.length == 2 ? double.tryParse(parts[0]) : null;
    final lng =
        parts != null && parts.length == 2 ? double.tryParse(parts[1]) : null;

    _supabase.from('sos_events').insert({
      'user_id': userId,
      'timestamp': DateTime.now().toIso8601String(),
      if (lat != null) 'latitude': lat,
      if (lng != null) 'longitude': lng,
      'contacts_count': _contacts.length,
      'success_count': successCount,
      'failure_count': failureCount,
    }).then((_) {
      debugPrint('[SOS] Event logged to Supabase');
    }).catchError((e) {
      debugPrint('[SOS] Event log failed (non-critical) — $e');
    });
  }

  // ─── Dialogs ───────────────────────────────────────────────────────────────

  Future<bool> _showConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101521),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Confirm SOS',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send SOS to all emergency contacts?',
              style: TextStyle(color: Color(0xFFB8BEC9), fontSize: 14),
            ),
            const SizedBox(height: 10),
            ..._contacts.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${c.name} (${c.phone})',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFFB8BEC9))),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style:
                FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('SEND SOS'),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showResultDialog(SosSendResult result) {
    final nameMap = {for (final c in _contacts) c.phone: c.name};

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101521),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: Color(0xFF4ADE80), size: 20),
            const SizedBox(width: 8),
            Text(
              'SOS Sent (${result.successCount}/${result.totalContacts})',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: result.results.map((r) {
            final name = nameMap[r.phone] ?? r.phone;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    r.succeeded ? Icons.check_circle : Icons.cancel,
                    size: 16,
                    color: r.succeeded
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFFF87171),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$name — ${r.statusLabel}',
                      style: TextStyle(
                        color: r.succeeded
                            ? const Color(0xFFF9FAFB)
                            : const Color(0xFF9CA3AF),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style:
                FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ─── Contacts sheet ────────────────────────────────────────────────────────

  Future<void> _openContactsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (sheetCtx, setS) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF101521),
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          padding: EdgeInsets.fromLTRB(
              14, 14, 14, 14 + MediaQuery.viewInsetsOf(sheetCtx).bottom),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Emergency Contacts',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(sheetCtx).pop(),
                      child: const Icon(Icons.close_rounded,
                          color: Color(0xFF9CA3AF), size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_contacts.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xAA141420),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2A2A3E)),
                    ),
                    child: const Text('No emergency contacts yet',
                        style: TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 13)),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _contacts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final c = _contacts[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xCC141420),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: const Color(0xFF2A2A3E)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(c.name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(c.phone,
                                        style: const TextStyle(
                                            color: Color(0xFF9CA3AF),
                                            fontSize: 12.5)),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  await _deleteContact(c.id);
                                  if (mounted) setS(() {});
                                },
                                icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Color(0xFFF87171),
                                    size: 20),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final added = await _openAddContactDialog();
                      if (mounted && added) setS(() {});
                    },
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 11)),
                    icon: const Icon(Icons.person_add_alt_1_rounded,
                        size: 18),
                    label: const Text('Add Contact'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _openAddContactDialog() async {
    if (_contacts.length >= 5) {
      _showSnack('Maximum 5 contacts allowed', isError: false);
      return false;
    }

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101521),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Add Emergency Contact',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _inputField(
                controller: nameCtrl,
                label: 'Name',
                hint: 'e.g., Rahul',
                keyboardType: TextInputType.name,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              _inputField(
                controller: phoneCtrl,
                label: 'Phone Number',
                hint: '10-digit number',
                keyboardType: TextInputType.number,
                validator: (v) {
                  final p = (v ?? '').trim();
                  if (p.isEmpty) return 'Required';
                  if (!RegExp(r'^\d{10}$').hasMatch(p)) {
                    return 'Enter exactly 10 digits';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFFB8BEC9))),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop(true);
            },
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED)),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (save != true) {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      return false;
    }

    final inserted = await _insertContact(
        name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim());
    nameCtrl.dispose();
    phoneCtrl.dispose();
    return inserted;
  }

  Future<bool> _insertContact(
      {required String name, required String phone}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _showSnack('Please login to add contacts', isError: true);
        return false;
      }
      await _supabase.from('emergency_contacts').insert({
        'user_id': userId,
        'name': name,
        'phone': phone,
      });
      await _loadContacts();
      return true;
    } catch (_) {
      _showSnack('Could not add contact', isError: true);
      return false;
    }
  }

  Future<void> _deleteContact(String id) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      await _supabase
          .from('emergency_contacts')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
      await _loadContacts();
    } catch (_) {
      _showSnack('Could not delete contact', isError: true);
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  void _showSnack(
    String text, {
    required bool isError,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor:
          isError ? const Color(0xFFEF4444) : const Color(0xFF1E293B),
      behavior: SnackBarBehavior.floating,
      action: action,
      duration: duration,
    ));
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required TextInputType keyboardType,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
        hintStyle:
            const TextStyle(color: Color(0xFF4B5563), fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF151B2A),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF2A2A3E))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF2A2A3E))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF7C3AED))),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFEF4444))),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 390;
    final buttonSize = isCompact ? 176.0 : 204.0;

    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF050510),
                Color(0xFF040713),
                Color(0xFF050510)
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -80,
                right: -70,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      Color(0x332A6BFF),
                      Color(0x00102440)
                    ]),
                  ),
                ),
              ),
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      isCompact ? 16 : 20, 16, isCompact ? 16 : 20, 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        children: [
                          SizedBox(height: isCompact ? 10 : 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  'Emergency SOS',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isCompact ? 31 : 34,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.1,
                                    height: 1.08,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _openContactsSheet,
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xCC141420),
                                  side: const BorderSide(
                                      color: Color(0xFF2A2A3E)),
                                ),
                                icon: const Icon(Icons.contacts_rounded,
                                    color: Color(0xFFB8BEC9), size: 20),
                              ),
                            ],
                          ),
                          SizedBox(height: isCompact ? 8 : 10),
                          const Text(
                            'Press the button below in case of a medical emergency',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color(0xFFB8BEC9),
                                fontSize: 15.2,
                                height: 1.45),
                          ),
                          SizedBox(height: isCompact ? 24 : 28),
                          _SosButton(
                            size: buttonSize,
                            sending: _sendingSos,
                            statusMessage: _sosStatus,
                            onTap: _handleSosTap,
                          ),
                          SizedBox(height: isCompact ? 24 : 30),
                          _EmergencyContactCard(
                            title: 'Emergency Contact',
                            value: 'Ambulance: 102',
                            phoneNumber: '102',
                          ),
                          const SizedBox(height: 10),
                          _EmergencyContactCard(
                            title: 'Trusted Contact Helpline',
                            value: 'National Emergency: 112',
                            phoneNumber: '112',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SOS Button ────────────────────────────────────────────────────────────

class _SosButton extends StatelessWidget {
  const _SosButton({
    required this.size,
    required this.sending,
    required this.statusMessage,
    required this.onTap,
  });

  final double size;
  final bool sending;
  final String statusMessage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCompact = size < 190;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: sending ? null : onTap,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: sending ? 0.85 : 1,
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                ),
                boxShadow: [
                  BoxShadow(
                      color: Color(0x55EF4444),
                      blurRadius: 30,
                      offset: Offset(0, 14))
                ],
              ),
              child: Center(
                child: sending
                    ? const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.white,
                              size: isCompact ? 56 : 64),
                          SizedBox(height: isCompact ? 4 : 6),
                          Text(
                            'SOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isCompact ? 23 : 25,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        if (sending && statusMessage.isNotEmpty) ...[
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              statusMessage,
              key: ValueKey(statusMessage),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB8BEC9),
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Emergency contact card ────────────────────────────────────────────────

class _EmergencyContactCard extends StatelessWidget {
  const _EmergencyContactCard({
    required this.title,
    required this.value,
    this.phoneNumber,
  });

  final String title;
  final String value;
  final String? phoneNumber;

  Future<void> _openDialer() async {
    if (phoneNumber == null) return;
    await launchUrl(Uri(scheme: 'tel', path: phoneNumber),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 390;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 13 : 14),
      decoration: BoxDecoration(
        color: const Color(0xCC141420),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: phoneNumber == null ? null : _openDialer,
            child: Container(
              width: isCompact ? 42 : 44,
              height: isCompact ? 42 : 44,
              decoration: BoxDecoration(
                color: const Color(0x33EF4444),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x66EF4444)),
              ),
              child: Icon(Icons.call,
                  color: const Color(0xFFF87171),
                  size: isCompact ? 20 : 22),
            ),
          ),
          SizedBox(width: isCompact ? 10 : 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 14 : 14.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(value,
                    style: TextStyle(
                        color: const Color(0xFFA1A8B3),
                        fontSize: isCompact ? 12.5 : 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Countdown dialog ──────────────────────────────────────────────────────

class _CountdownDialog extends StatefulWidget {
  const _CountdownDialog({
    required this.onComplete,
    required this.onCancel,
  });

  final VoidCallback onComplete;
  final VoidCallback onCancel;

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  int _count = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _count--);
      if (_count <= 0) {
        t.cancel();
        Navigator.of(context).pop();
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF101521),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Sending SOS in...',
              style: TextStyle(color: Color(0xFFB8BEC9), fontSize: 14)),
          const SizedBox(height: 16),
          Text(
            '$_count',
            style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 72,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                _timer?.cancel();
                Navigator.of(context).pop();
                widget.onCancel();
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2A2A3E)),
                foregroundColor: const Color(0xFFB8BEC9),
              ),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Model ─────────────────────────────────────────────────────────────────

class _EmergencyContact {
  const _EmergencyContact(
      {required this.id, required this.name, required this.phone});

  final String id;
  final String name;
  final String phone;

  factory _EmergencyContact.fromRow(Map<String, dynamic> row) =>
      _EmergencyContact(
        id: (row['id'] ?? '').toString(),
        name: (row['name'] ?? '').toString(),
        phone: (row['phone'] ?? '').toString(),
      );
}
