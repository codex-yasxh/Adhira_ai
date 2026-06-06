import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../core/theme/app_theme.dart';
import '../pages/chat_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/login_page.dart';
import '../pages/medicines_page.dart';
import '../pages/reminders_page.dart';
import '../pages/sos_page.dart';
import '../services/notification_service.dart';

class AdhiraApp extends StatelessWidget {
  const AdhiraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adhira',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const _SplashScreen(),
      routes: <String, WidgetBuilder>{
        '/home': (_) => const _MainNavShell(),
        '/login': (_) => const LoginPage(),
      },
    );
  }
}

// ── Splash ────────────────────────────────────────────────────────────────────

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initAndNavigate();
  }

  Future<void> _initAndNavigate() async {
    // Run minimum splash duration and session check in parallel
    await Future.wait(<Future<void>>[
      Future<void>.delayed(const Duration(milliseconds: 1800)),
      _checkSession(),
    ]);
    if (!mounted) return;
    final Session? session = Supabase.instance.client.auth.currentSession;
    Navigator.of(
      context,
    ).pushReplacementNamed(session != null ? '/home' : '/login');
  }

  Future<void> _checkSession() async {
    try {
      await Supabase.instance.client.auth.refreshSession();
    } catch (_) {
      // no session or refresh failed — will fall through to login
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const <Widget>[
              Text(
                'ADHIRA',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Your personal health assistant',
                style: TextStyle(fontSize: 14, color: Color(0xFFB8BEC9)),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Main Nav Shell ────────────────────────────────────────────────────────────

class _MainNavShell extends StatefulWidget {
  const _MainNavShell();

  @override
  State<_MainNavShell> createState() => _MainNavShellState();
}

class _MainNavShellState extends State<_MainNavShell> {
  int _selectedIndex = 2;
  StreamSubscription<String>? _notificationTapSubscription;
  late final List<GlobalKey<NavigatorState>> _navigatorKeys =
      List<GlobalKey<NavigatorState>>.generate(
        5,
        (_) => GlobalKey<NavigatorState>(),
      );

  late final List<Widget> _tabRoots = <Widget>[
    const DashboardPage(),
    const MedicinesPage(),
    const ChatPage(),
    const RemindersPage(),
    const SosPage(),
  ];

  @override
  void initState() {
    super.initState();
    _notificationTapSubscription = NotificationService
        .instance
        .onNotificationTap
        .listen(_handleNotificationPayload);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = NotificationService.instance.consumePendingPayload();
      if (pending != null) _handleNotificationPayload(pending);
    });
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
    super.dispose();
  }

  void _handleNotificationPayload(String payload) {
    if (!mounted) return;
    if (payload == NotificationService.remindersPayload) {
      setState(() => _selectedIndex = 3);
    }
  }

  Future<bool> _onWillPop() async {
    final NavigatorState? currentNavigator =
        _navigatorKeys[_selectedIndex].currentState;
    if (currentNavigator != null && currentNavigator.canPop()) {
      currentNavigator.pop();
      return false;
    }
    return true;
  }

  Widget _buildTabNavigator(int index) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (RouteSettings settings) {
        return MaterialPageRoute<void>(
          builder: (_) => _tabRoots[index],
          settings: settings,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final bool shouldPopApp = await _onWillPop();
        if (shouldPopApp && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: List<Widget>.generate(_tabRoots.length, _buildTabNavigator),
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: const Color(0xFF050510),
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          indicatorColor: const Color(0xFF26314A),
          height: 70,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
            Set<WidgetState> states,
          ) {
            final bool selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: selected
                  ? const Color(0xFFE7ECF7)
                  : const Color(0xFF8C93A0),
            );
          }),
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) {
            if (index == _selectedIndex) {
              _navigatorKeys[index].currentState?.popUntil(
                (route) => route.isFirst,
              );
              return;
            }
            setState(() => _selectedIndex = index);
          },
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(
                Icons.monitor_heart_outlined,
                size: 20,
                color: Color(0xFF8C93A0),
              ),
              selectedIcon: Icon(
                Icons.monitor_heart_outlined,
                size: 20,
                color: Color(0xFFE7ECF7),
              ),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.medication_outlined,
                size: 20,
                color: Color(0xFF8C93A0),
              ),
              selectedIcon: Icon(
                Icons.medication_outlined,
                size: 20,
                color: Color(0xFFE7ECF7),
              ),
              label: 'Medicines',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.all_inclusive_outlined,
                size: 20,
                color: Color(0xFF8C93A0),
              ),
              selectedIcon: Icon(
                Icons.all_inclusive_outlined,
                size: 20,
                color: Color(0xFFE7ECF7),
              ),
              label: 'Chat',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.notifications_none_outlined,
                size: 20,
                color: Color(0xFF8C93A0),
              ),
              selectedIcon: Icon(
                Icons.notifications_none_outlined,
                size: 20,
                color: Color(0xFFE7ECF7),
              ),
              label: 'Reminders',
            ),
            NavigationDestination(
              icon: Icon(Icons.diversity_1, size: 20, color: Color(0xFF8C93A0)),
              selectedIcon: Icon(
                Icons.diversity_1,
                size: 20,
                color: Color(0xFFE7ECF7),
              ),
              label: 'SOS',
            ),
          ],
        ),
      ),
    );
  }
}
