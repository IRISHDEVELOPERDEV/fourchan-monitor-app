import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api.dart';
import 'feed_screen.dart';
import 'archives_screen.dart';
import 'settings_screen.dart';

/// Background/terminated push handler (must be a top-level function).
/// Notification-payload messages are shown by the OS automatically, so this can
/// stay empty — it just needs to exist for FCM to register the isolate.
@pragma('vm:entry-point')
Future<void> _fcmBackground(RemoteMessage message) async {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Config.load();
  await _initPush(); // best-effort; the app still works if push isn't available
  runApp(const MonitorApp());
}

/// Set up Firebase Cloud Messaging so the app gets the same EE/Emily alerts as
/// Telegram, even when it's closed. Registers this device's token with the server.
Future<void> _initPush() async {
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_fcmBackground);
    final fm = FirebaseMessaging.instance;
    await fm.requestPermission(alert: true, badge: true, sound: true);
    final token = await fm.getToken();
    if (token != null) await Api.registerDevice(token);
    fm.onTokenRefresh.listen(Api.registerDevice);
  } catch (_) {
    // Push is optional — never let a Firebase hiccup stop the app from opening.
  }
}

const _clover = Color(0xFF43B14B); // X4chan clover green

ThemeData _buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: _clover, brightness: b);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        dark ? const Color(0xFF0E0F11) : const Color(0xFFF5F6F8),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF0E0F11) : Colors.white,
      foregroundColor: dark ? Colors.white : const Color(0xFF15171A),
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: dark ? Colors.white : const Color(0xFF15171A)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF121417) : Colors.white,
      indicatorColor: _clover.withOpacity(dark ? 0.22 : 0.16),
    ),
  );
}

class MonitorApp extends StatelessWidget {
  const MonitorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) => MaterialApp(
        title: 'X4chan',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: const Home(),
      ),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _i = 0;
  final _pages = const [FeedScreen(), ArchivesScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_i],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dynamic_feed), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.travel_explore), label: 'Archive'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
