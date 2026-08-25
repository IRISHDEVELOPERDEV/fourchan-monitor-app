import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'emote_text.dart';

/// Look up a Twitch user's chat logs in two steps: type their name to see which
/// channels they actually appear in, then pick a channel to read what they said.
/// You can also type a channel directly to go straight there.
class TwitchScreen extends StatefulWidget {
  const TwitchScreen({super.key});
  @override
  State<TwitchScreen> createState() => _TwitchScreenState();
}

class _TwitchScreenState extends State<TwitchScreen> {
  static const _green = Color(0xFF43B14B);
  final _user = TextEditingController();
  final _channel = TextEditingController();

  List<TwitchChannelHit> _hits = [];
  List<TwitchMsg> _msgs = [];
  Map<String, String> _emotes = {};
  String? _openChannel; // channel we're currently reading
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _channel.dispose();
    super.dispose();
  }

  Color _muted(BuildContext c) =>
      Theme.of(c).colorScheme.onSurface.withOpacity(0.6);

  /// Step 1: which channels is this person in?
  Future<void> _findChannels() async {
    final user = _user.text.trim();
    if (user.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
      _msgs = [];
      _openChannel = null;
      _hits = [];
    });
    try {
      final hits = await Api.twitchUserChannels(user);
      if (!mounted) return;
      setState(() {
        _hits = hits;
        if (hits.isEmpty) {
          _error = 'No logs found for that name in the channels searched.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach the log service.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Step 2: read what they said in one channel.
  Future<void> _openLogs(String channel) async {
    final user = _user.text.trim();
    if (user.isEmpty || channel.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
      _openChannel = channel;
      _msgs = [];
    });
    try {
      final r = await Api.twitchLogs(user, channel: channel);
      if (!mounted) return;
      setState(() {
        _msgs = r.messages;
        if (r.messages.isEmpty) _error = r.error ?? 'Nothing found there.';
      });
      // Emotes load after the text so messages appear straight away, then the
      // 7TV/BTTV/FFZ images fill in.
      final em = await Api.twitchEmotes(channel);
      if (mounted) setState(() => _emotes = em);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach the log service.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final title = _openChannel == null
        ? 'Twitch logs'
        : '#${_openChannel!} · ${_user.text.trim()}';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: _openChannel != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _openChannel = null;
                  _msgs = [];
                  _error = null;
                }),
              )
            : null,
      ),
      body: Column(children: [
        if (_openChannel == null) _searchBar(),
        if (_loading) const LinearProgressIndicator(),
        Expanded(child: _body(dark)),
      ]),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(children: [
        TextField(
          controller: _user,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _findChannels(),
          decoration: InputDecoration(
            labelText: 'Twitch username',
            hintText: 'e.g. extraemily',
            prefixIcon: const Icon(Icons.person_search),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: _findChannels,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _channel,
              textInputAction: TextInputAction.go,
              onSubmitted: (v) => _openLogs(v.trim()),
              decoration: const InputDecoration(
                labelText: 'Or go straight to a channel',
                hintText: 'e.g. nmplol',
                prefixIcon: Icon(Icons.tv),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => _openLogs(_channel.text.trim()),
            child: const Text('Go'),
          ),
        ]),
      ]),
    );
  }

  Widget _body(bool dark) {
    if (_openChannel != null) return _messageList(dark);

    if (!_searched) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Type a Twitch username to see which channels they chat in.\n\n'
            'Then tap a channel to read their messages there.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted(context)),
          ),
        ),
      );
    }
    if (_hits.isEmpty && !_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(_error ?? 'Nothing found.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted(context))),
        ),
      );
    }
    return ListView.builder(
      itemCount: _hits.length + 1,
      itemBuilder: (c, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Text('Found in ${_hits.length} channel(s) — tap to read',
                style: TextStyle(color: _muted(context), fontSize: 12)),
          );
        }
        final h = _hits[i - 1];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF17191C) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.18)),
          ),
          child: ListTile(
            leading: const Icon(Icons.tv, color: _green),
            title: Text('#${h.channel}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${h.count} message(s) · last ${h.lastDay}',
                style: TextStyle(color: _muted(context), fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openLogs(h.channel),
          ),
        );
      },
    );
  }

  Widget _messageList(bool dark) {
    if (_msgs.isEmpty && !_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(_error ?? 'Nothing found.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted(context))),
        ),
      );
    }
    return ListView.builder(
      itemCount: _msgs.length + 1,
      itemBuilder: (c, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Text('${_msgs.length} message(s), newest first',
                style: TextStyle(color: _muted(context), fontSize: 12)),
          );
        }
        final m = _msgs[i - 1];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF17191C) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.18)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text('${m.name} · ${m.when}',
                    style: TextStyle(fontSize: 11, color: _muted(context))),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: m.text));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Copied'),
                      duration: Duration(milliseconds: 800)));
                },
                child: Icon(Icons.copy, size: 15, color: _muted(context)),
              ),
            ]),
            const SizedBox(height: 6),
            EmoteText(m, _emotes,
                style: const TextStyle(fontSize: 14.5, height: 1.35)),
          ]),
        );
      },
    );
  }
}
