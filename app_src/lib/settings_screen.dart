import 'package:flutter/material.dart';
import 'api.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _url = TextEditingController(text: Config.baseUrl);
  late final _tok = TextEditingController(text: Config.token);
  String _status = 'Checking…';

  @override
  void initState() {
    super.initState();
    _refresh();
    feedRefresh.addListener(_onFilterChanged); // stay in sync with the Feed's toggle
  }

  void _onFilterChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    try {
      final h = await Api.health();
      setState(() => _status = 'Connected — mode: ${h['mode']}, '
          'keywords: ${(h['keywords'] as List).join(', ')}');
    } catch (e) {
      setState(() => _status = 'Not connected: $e');
    }
  }

  @override
  void dispose() {
    feedRefresh.removeListener(_onFilterChanged);
    _url.dispose();
    _tok.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Local feed filter — same control as the Feed's All · EE/Emily toggle.
        // Only changes what YOU see in the app; never touches Telegram.
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: const Color(0xFF43B14B),
          title: const Text('Only show EE / Emily'),
          subtitle: const Text('On = just EE / Emily mentions · Off = all posts'),
          value: Config.keywordsOnly,
          onChanged: (v) async {
            await Config.setKeywordsOnly(v); // persists + updates the Feed too
            if (mounted) setState(() {});
          },
        ),
        const Divider(height: 28),
        TextField(
          controller: _url,
          decoration: const InputDecoration(
              labelText: 'Server URL', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tok,
          decoration: const InputDecoration(
              labelText: 'API token', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            await Config.save(_url.text, _tok.text);
            await _refresh();
          },
          child: const Text('Save & connect'),
        ),
        const SizedBox(height: 20),
        Text(_status, style: TextStyle(color: Colors.grey.shade400)),
      ]),
    );
  }
}
