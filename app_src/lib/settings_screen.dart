import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Future<void> _addReply() async {
    final c = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New saved reply'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
              hintText: 'Something you type often…', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (text != null && text.isNotEmpty) {
      await Config.setSavedReplies([...Config.savedReplies, text]);
      if (mounted) setState(() {});
    }
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
          _section('Notifications', Icons.notifications_outlined, [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: _green,
              title: const Text('Push alerts to this phone'),
              subtitle:
                  const Text('EE / Emily alerts even when the app is closed'),
              value: Config.notificationsEnabled,
              onChanged: (v) async {
                await Config.setNotificationsEnabled(v);
                final t = fcmToken;
                if (t != null) {
                  if (v) {
                    await Api.registerDevice(t);
                  } else {
                    await Api.unregisterDevice(t);
                  }
                }
                if (mounted) setState(() {});
              },
            ),
          ]),
          _section('4chan Pass', Icons.badge_outlined, [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Your Pass lives in your browser, not in this app. Log in once '
                'below and every Reply from X4chan posts as a Pass user with no '
                'captcha. The login stays in your browser for about a year.',
                style: TextStyle(color: _muted(context), fontSize: 12.5, height: 1.35),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () => launchUrl(
                    Uri.parse('https://sys.4chan.org/auth'),
                    mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Log in to my 4chan Pass'),
              ),
            ),
          ]),
          _section('Auto-fill replies (optional)', Icons.auto_fix_high, [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Install this one-time browser add-on and your saved replies get '
                'typed into the 4chan reply box for you — you still read it and '
                'press Post. Needs a browser that supports userscripts (Firefox '
                'with Violentmonkey, or Kiwi Browser).',
                style: TextStyle(color: _muted(context), fontSize: 12.5, height: 1.35),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () => launchUrl(
                    Uri.parse('${Config.baseUrl}/userscript'),
                    mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Install the auto-fill add-on'),
              ),
            ),
          ]),
          _section('Saved replies', Icons.bolt, [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Long-press Reply on any post to copy one of these and jump '
                'straight to the reply box for that thread.',
                style: TextStyle(color: _muted(context), fontSize: 12.5, height: 1.35),
              ),
            ),
            for (int i = 0; i < Config.savedReplies.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.bolt, size: 18, color: _green),
                title: Text(Config.savedReplies[i],
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () async {
                    final list = [...Config.savedReplies]..removeAt(i);
                    await Config.setSavedReplies(list);
                    if (mounted) setState(() {});
                  },
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addReply,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add a reply'),
              ),
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
