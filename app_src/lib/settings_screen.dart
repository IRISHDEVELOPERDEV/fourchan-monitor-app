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
    _url.dispose();
    _tok.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
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
        const Divider(height: 32),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'To switch between all posts and only EE / Emily, use the '
              'All · EE / Emily toggle at the top of the Feed.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.4),
            ),
          ),
        ]),
      ]),
    );
  }
}
