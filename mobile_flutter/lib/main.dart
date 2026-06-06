import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://qyiuyweywoqtrltrawgk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF5aXV5d2V5d29xdHJsdHJhd2drIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg1ODYxMjIsImV4cCI6MjA5NDE2MjEyMn0.vwqv7DrFNxjDUXDEjDgKwvwYLwDyRBTqVDfwNuhzUU0',
  );

  await NotificationService.instance.init();

  runApp(const AdhiraApp());
}
