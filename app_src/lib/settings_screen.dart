import 'package:flutter/material.dart';
import 'api.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _green = Color(0xFF43B14B);
  String _status = 'Checking…';
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    feedRefresh.addListener(_onChange); // keep the filter switch in sync with the Feed
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    feedRefresh.removeListener(_onChange);
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final h = await Api.health();
      if (!mounted) return;
      setState(() {
        _connected = true;
        _status = 'Connected — watching ${(h['keywords'] as List).join(', ')}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _connected = false;
        _status = 'Not connected — will keep trying';
      });
    }
  }

  Color _muted(BuildContext c) =>
      Theme.of(c).colorScheme.onSurface.withOpacity(0.6);

  Widget _section(String title, IconData icon, List<Widget> children) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF17191C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: _green),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        const SizedBox(height: 8),
        ...children,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          _section('Appearance', Icons.palette_outlined, [
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 2),
              child: Text('Theme', style: TextStyle(color: _muted(context))),
            ),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto, size: 16)),
                  ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode, size: 16)),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode, size: 16)),
                ],
                selected: {Config.themeMode},
                onSelectionChanged: (s) => Config.setThemeMode(s.first),
              ),
            ),
          ]),
          _section('Feed', Icons.dynamic_feed, [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: _green,
              title: const Text('Only show EE / Emily'),
              subtitle: const Text('On = just mentions · Off = all posts'),
              value: Config.keywordsOnly,
              onChanged: (v) async {
                await Config.setKeywordsOnly(v);
                if (mounted) setState(() {});
              },
            ),
          ]),
          _section('Connection', Icons.cloud_outlined, [
            Row(children: [
              Icon(Icons.circle,
                  size: 12, color: _connected ? _green : Colors.redAccent),
              const SizedBox(width: 10),
              Expanded(child: Text(_status)),
              IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Re-check'),
            ]),
          ]),
          const SizedBox(height: 6),
          Center(
            child: Text('X4chan · watches /b/ for EE & Emily',
                style: TextStyle(color: _muted(context), fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
