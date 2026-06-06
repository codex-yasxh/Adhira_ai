import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/notification_service.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final List<_Reminder> _reminders = <_Reminder>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await NotificationService.instance.requestPermissions();
    await NotificationService.instance.clearLegacySchedulesOnce();
    await _loadReminders();
    _rescheduleEnabledReminders();
  }

  Future<void> _loadReminders() async {
    try {
      final String? userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final List<dynamic> rows = await _supabase
          .from('reminders')
          .select('*')
          .eq('user_id', userId)
          .order('id', ascending: true);

      final List<_Reminder> loaded = rows
          .whereType<Map<String, dynamic>>()
          .map(_mapReminderFromRow)
          .toList();

      if (!mounted) return;
      setState(() {
        _reminders
          ..clear()
          ..addAll(loaded);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load reminders from server'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  _Reminder _mapReminderFromRow(Map<String, dynamic> row) {
    final String dbId = _stringFrom(row['id']) ?? '';
    final String title =
        _stringFrom(row['title']) ?? _stringFrom(row['name']) ?? 'Reminder';
    final String medName =
        _stringFrom(row['med_name']) ??
        _stringFrom(row['medicine_name']) ??
        title;
    final String dosage =
        _stringFrom(row['dosage']) ??
        _stringFrom(row['medicine_dosage']) ??
        'as prescribed';
    final String time =
        _stringFrom(row['time']) ??
        _stringFrom(row['reminder_time']) ??
        '09:00 AM';
    final bool enabled =
        _boolFrom(row['enabled']) ?? _boolFrom(row['is_enabled']) ?? false;

    return _Reminder(
      id: dbId,
      title: title,
      medName: medName,
      dosage: dosage,
      time: time,
      enabled: enabled,
    );
  }

  String? _stringFrom(dynamic value) {
    final String text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }

  bool? _boolFrom(dynamic value) {
    if (value is bool) return value;
    final String text = (value ?? '').toString().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return null;
  }

  void _rescheduleEnabledReminders() {
    for (final _Reminder reminder in _reminders) {
      if (reminder.enabled) {
        _scheduleReminder(reminder);
      }
    }
  }

  void _scheduleReminder(_Reminder reminder) {
    final int notificationId = _notificationIdFromDbId(reminder.id);
    NotificationService.instance.scheduleReminder(
      id: notificationId,
      medName: reminder.medName,
      dosage: reminder.dosage,
      time: reminder.time,
    );
  }

  void _cancelReminder(_Reminder reminder) {
    final int notificationId = _notificationIdFromDbId(reminder.id);
    NotificationService.instance.cancelReminder(notificationId);
  }

  void _toggleReminder(String id) {
    setState(() {
      final _Reminder reminder = _reminders.firstWhere((r) => r.id == id);
      reminder.enabled = !reminder.enabled;
      if (reminder.enabled) {
        _scheduleReminder(reminder);
      } else {
        _cancelReminder(reminder);
      }
    });

    _updateReminderEnabled(id);
  }

  void _deleteReminder(String id) {
    final _Reminder reminder = _reminders.firstWhere((r) => r.id == id);
    _cancelReminder(reminder);
    setState(() => _reminders.removeWhere((r) => r.id == id));
    _deleteReminderFromServer(id);
  }

  Future<void> _openAddSheet() async {
    final _ReminderFormResult? result =
        await showModalBottomSheet<_ReminderFormResult>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _AddReminderSheet(),
        );
    if (result == null) return;

    final _Reminder draftReminder = _Reminder(
      id: '',
      title: result.title,
      medName: result.title,
      dosage: 'as prescribed',
      time: result.time,
      enabled: true,
    );
    final _Reminder? savedReminder = await _createReminderOnServer(
      draftReminder,
    );
    if (savedReminder == null) return;
    setState(() => _reminders.add(savedReminder));
    _scheduleReminder(savedReminder);
    await NotificationService.instance.showReminderConfirmation(
      medName: savedReminder.medName,
      time: savedReminder.time,
    );

    if (NotificationService.parseTime(result.time) == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reminder added but notification could not be scheduled. Use format like 09:00 AM.',
          ),
          backgroundColor: Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<_Reminder?> _createReminderOnServer(_Reminder reminder) async {
    try {
      final String? userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to save reminders'),
            backgroundColor: Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return null;
      }
      Map<String, dynamic> row;
      try {
        row = await _supabase
            .from('reminders')
            .insert(<String, dynamic>{
              'user_id': userId,
              'title': reminder.title,
              'time': reminder.time,
              'enabled': reminder.enabled,
            })
            .select()
            .single();
      } catch (_) {
        row = await _supabase
            .from('reminders')
            .insert(<String, dynamic>{
              'user_id': userId,
              'title': reminder.title,
              'time': reminder.time,
              'is_enabled': reminder.enabled,
            })
            .select()
            .single();
      }
      final _Reminder saved = _mapReminderFromRow(row);
      return saved;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save reminder to server: $e'),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }
  }

  Future<void> _deleteReminderFromServer(String id) async {
    try {
      final String? userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final query = _supabase
          .from('reminders')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
      await query;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete reminder from server: $e'),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _updateReminderEnabled(String id) async {
    final _Reminder reminder = _reminders.firstWhere((r) => r.id == id);
    try {
      final String? userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      try {
        await _supabase
            .from('reminders')
            .update(<String, dynamic>{'enabled': reminder.enabled})
            .eq('id', id)
            .eq('user_id', userId);
      } catch (_) {
        await _supabase
            .from('reminders')
            .update(<String, dynamic>{'is_enabled': reminder.enabled})
            .eq('id', id)
            .eq('user_id', userId);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not sync reminder status to server: $e'),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
              colors: <Color>[
                Color(0xFF050510),
                Color(0xFF040713),
                Color(0xFF050510),
              ],
              stops: <double>[0.0, 0.45, 1.0],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Reminders',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Manage your health reminders',
                                style: TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _openAddSheet,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text(
                            'Add Reminder',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (_reminders.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xAA141420),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF2A2A3E)),
                        ),
                        child: const Text(
                          'No reminders yet. Tap Add Reminder to get started.',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _reminders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, int i) {
                          final _Reminder reminder = _reminders[i];
                          return _ReminderCard(
                            reminder: reminder,
                            onToggle: () => _toggleReminder(reminder.id),
                            onDelete: () => _deleteReminder(reminder.id),
                          );
                        },
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

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.onToggle,
    required this.onDelete,
  });

  final _Reminder reminder;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool on = reminder.enabled;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: on ? 1.0 : 0.55,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: on ? const Color(0x0F7C3AED) : const Color(0xAA141420),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: on ? const Color(0x557C3AED) : const Color(0xFF2A2A3E),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: on ? const Color(0x227C3AED) : const Color(0xFF1A1F2D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: on ? const Color(0x557C3AED) : const Color(0xFF2A2A3E),
                ),
              ),
              child: Icon(
                Icons.notifications_rounded,
                size: 20,
                color: on ? const Color(0xFFA78BFA) : const Color(0xFF4B5563),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    reminder.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.access_time_rounded,
                        size: 11,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        reminder.time,
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
                      ),
                      if (on) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x227C3AED),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Daily',
                            style: TextStyle(
                              color: Color(0xFFA78BFA),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: on ? const Color(0xFF7C3AED) : const Color(0xFF2A2A3E),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddReminderSheet extends StatefulWidget {
  const _AddReminderSheet();

  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _timeCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF101521),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: EdgeInsets.fromLTRB(
        14,
        14,
        14,
        14 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Add Reminder',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF9CA3AF),
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _field(
                _titleCtrl,
                'Reminder Title',
                'e.g., Take Paracetamol 500mg',
              ),
              const SizedBox(height: 8),
              _field(
                _timeCtrl,
                'Time',
                'e.g., 09:00 AM',
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) return 'Required';
                  if (NotificationService.parseTime(value.trim()) == null) {
                    return 'Use format like 09:00 AM or 14:30';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 6),
              const Text(
                'Use format: 09:00 AM or 14:30',
                style: TextStyle(color: Color(0xFF4B5563), fontSize: 11),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2A2A3E)),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        Navigator.of(context).pop(
                          _ReminderFormResult(
                            title: _titleCtrl.text.trim(),
                            time: _timeCtrl.text.trim(),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                      ),
                      child: const Text('Add Reminder'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      validator:
          validator ??
          (String? value) =>
              (value == null || value.trim().isEmpty) ? 'Required' : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
        hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF151B2A),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
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
          borderSide: const BorderSide(color: Color(0xFF7C3AED)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
      ),
    );
  }
}

class _Reminder {
  _Reminder({
    required this.id,
    required this.title,
    required this.medName,
    required this.dosage,
    required this.time,
    required this.enabled,
  });

  final String id;
  final String title;
  final String medName;
  final String dosage;
  final String time;
  bool enabled;
}

int _notificationIdFromDbId(String dbId) {
  // Deterministic positive hash for stable notification IDs across restarts.
  int hash = 0;
  for (final int unit in dbId.codeUnits) {
    hash = ((hash * 31) + unit) & 0x7fffffff;
  }
  return hash;
}

class _ReminderFormResult {
  const _ReminderFormResult({required this.title, required this.time});

  final String title;
  final String time;
}
