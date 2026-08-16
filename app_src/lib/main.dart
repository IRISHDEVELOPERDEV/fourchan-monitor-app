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

class MonitorApp extends StatelessWidget {
  const MonitorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'X4chan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF43B14B),   // X4chan clover green
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0E0F11),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0E0F11),
          centerTitle: false,
          titleTextStyle: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      home: const Home(),
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
