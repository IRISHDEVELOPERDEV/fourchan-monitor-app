import 'package:flutter/material.dart';
import 'api.dart';
import 'feed_screen.dart';
import 'archives_screen.dart';
import 'settings_screen.dart';

// v1: feed + search + settings + live auto-refresh (no Firebase push yet).
// Push notifications are added in v2 once the Firebase project is set up.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Config.load();
  runApp(const MonitorApp());
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
