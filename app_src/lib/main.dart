import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api.dart';
import 'post_detail_screen.dart';
import 'feed_screen.dart';
import 'archives_screen.dart';
import 'reply_browser.dart';
import 'twitch_screen.dart';
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
    fcmToken = token;
    if (token != null && Config.notificationsEnabled) {
      await Api.registerDevice(token);
    }
    fm.onTokenRefresh.listen((t) {
      fcmToken = t;
      if (Config.notificationsEnabled) Api.registerDevice(t);
    });
    // Tapping a notification opens the exact post it was about.
    fm.getInitialMessage().then(_openFromMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);
  } catch (_) {
    // Push is optional — never let a Firebase hiccup stop the app from opening.
  }
}

void _openFromMessage(RemoteMessage? m) {
  final no = int.tryParse(m?.data['no'] ?? '');
  if (no == null) return;
  // Cold launch from a notification: the navigator may not exist for a few
  // frames. Retry a bounded number of times so a failure can't spin forever.
  var tries = 0;
  void go() {
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.push(MaterialPageRoute(builder: (_) => PostDetailScreen(no: no)));
    } else if (++tries < 120) {
      WidgetsBinding.instance.addPostFrameCallback((_) => go());
    }
  }
  go();
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
        navigatorKey: navigatorKey,
        restorationScopeId: 'x4chan',
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
  bool _browseOpened = false;   // build the webview only once you visit the tab

  // IndexedStack keeps each tab alive, so the browser keeps its page and your
  // Pass session instead of reloading every time you switch away and back.
  List<Widget> get _pages => [
        const FeedScreen(),
        const ArchivesScreen(),
        _browseOpened
            ? const ReplyBrowser(
                url: 'https://boards.4chan.org/b/',
                title: 'Browse',
                showBack: false,
              )
            : const SizedBox.shrink(),
        const TwitchScreen(),
        const SettingsScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _i, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() {
          _i = v;
          if (v == 2) _browseOpened = true;
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dynamic_feed), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.travel_explore), label: 'Archive'),
          NavigationDestination(icon: Icon(Icons.public), label: 'Browse'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Twitch'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
