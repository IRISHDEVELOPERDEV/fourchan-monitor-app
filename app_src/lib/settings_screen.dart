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
  bool? _verbose;
  String _status = 'Not connected';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final h = await Api.health();
      final v = await Api.getVerbose();
      setState(() {
        _verbose = v;
        _status = 'Connected — mode: ${h['mode']}, '
            'keywords: ${(h['keywords'] as List).join(', ')}';
      });
    } catch (e) {
      setState(() => _status = 'Not connected: $e');
    }
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
        const Divider(height: 32),
        SwitchListTile(
          title: const Text('Show everything'),
          subtitle: const Text('On = all replies · Off = only EE / Emily'),
          value: _verbose ?? false,
          onChanged: _verbose == null
              ? null
              : (v) async {
                  final nv = await Api.setVerbose(v);
                  setState(() => _verbose = nv);
                },
        ),
        const SizedBox(height: 16),
        Text(_status, style: TextStyle(color: Colors.grey.shade400)),
      ]),
    );
  }
}
