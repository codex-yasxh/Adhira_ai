import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  static const String remindersPayload = 'reminders';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _tapStream =
      StreamController<String>.broadcast();

  bool _initialized = false;
  String? _pendingPayload;
  static const String _cleanupKey = 'notification_cleanup_done_v1';

  Stream<String> get onNotificationTap => _tapStream.stream;

  String? consumePendingPayload() {
    final payload = _pendingPayload;
    _pendingPayload = null;
    return payload;
  }

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const AndroidInitializationSettings android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final String? payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _tapStream.add(payload);
        }
      },
    );

    await requestPermissions();

    final NotificationAppLaunchDetails? launchDetails = await _plugin
        .getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final String? payload = launchDetails?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        _pendingPayload = payload;
      }
    }

    _initialized = true;
  }

  Future<void> clearLegacySchedulesOnce() async {
    await init();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool done = prefs.getBool(_cleanupKey) ?? false;
    if (done) return;
    await _plugin.cancelAll();
    await prefs.setBool(_cleanupKey, true);
  }

  Future<void> requestPermissions() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  Future<void> scheduleReminder({
    required int id,
    required String medName,
    required String dosage,
    required String time,
  }) async {
    final parsed = parseTime(time);
    if (parsed == null) return;
    await scheduleDaily(
      id: id,
      title: '💊 Medicine Reminder',
      body: 'Time to take $medName — $dosage',
      hour: parsed.hour,
      minute: parsed.minute,
    );
  }

  Future<void> showReminderConfirmation({
    required String medName,
    required String time,
  }) async {
    await init();
    await _plugin.show(
      88888,
      '✅ Reminder Set',
      'You\'ll be reminded to take $medName at $time',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'adhira_confirmation',
          'Reminder Confirmations',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  Future<void> cancelReminder(int id) async {
    await cancel(id);
  }

  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await init();

    final tz.TZDateTime scheduledTime = _nextInstanceOf(hour, minute);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'adhira_reminders',
          'Medicine Reminders',
          channelDescription: 'Daily medicine reminder notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: remindersPayload,
    );
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static ({int hour, int minute})? parseTime(String timeStr) {
    try {
      final String t = timeStr.trim().toUpperCase();

      final RegExp ampm = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$');
      final Match? match = ampm.firstMatch(t);
      if (match != null) {
        int hour = int.parse(match.group(1)!);
        final int minute = int.parse(match.group(2)!);
        final String period = match.group(3)!;
        if (period == 'AM' && hour == 12) hour = 0;
        if (period == 'PM' && hour != 12) hour += 12;
        if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
        return (hour: hour, minute: minute);
      }

      final RegExp h24 = RegExp(r'^(\d{1,2}):(\d{2})$');
      final Match? match24 = h24.firstMatch(t);
      if (match24 != null) {
        final int hour = int.parse(match24.group(1)!);
        final int minute = int.parse(match24.group(2)!);
        if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
        return (hour: hour, minute: minute);
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
