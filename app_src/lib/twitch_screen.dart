import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'emote_text.dart';

/// Look up a Twitch user's chat logs in two steps: type their name to see which
/// channels they appear in, then pick a channel to read what they said there.
/// The log itself is laid out one line per message — timestamp, badges, name,
/// text — with emotes drawn inline, like the public log viewers.
class TwitchScreen extends StatefulWidget {
  const TwitchScreen({super.key});
  @override
  State<TwitchScreen> createState() => _TwitchScreenState();
}

class _TwitchScreenState extends State<TwitchScreen> {
  static const _green = Color(0xFF43B14B);
  final _user = TextEditingController();
  final _channel = TextEditingController();
  final _find = TextEditingController();

  List<TwitchChannelHit> _hits = [];
  List<TwitchMsg> _msgs = [];
  Map<String, String> _emotes = {};
  Map<String, String> _badges = {};
  List<TwitchMonth> _months = [];
  String _period = '';           // "" = all time, else "2026-08"
  bool _oldestFirst = false;
  String? _openChannel;
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _channel.dispose();
    _find.dispose();
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

  /// Step 2: read what they said in one channel (optionally one month).
  Future<void> _openLogs(String channel, {String period = ''}) async {
    final user = _user.text.trim();
    if (user.isEmpty || channel.isEmpty) return;
    FocusScope.of(context).unfocus();
    final sameChannel = channel == _openChannel;
    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
      _openChannel = channel;
      _period = period;
      _msgs = [];
      if (!sameChannel) {
        _months = [];
        _find.clear();
      }
    });
    try {
      final results = await Future.wait([
        Api.twitchLogs(user, channel: channel, period: period),
        sameChannel
            ? Future.value(_months)
            : Api.twitchMonths(channel, user).catchError((_) => <TwitchMonth>[]),
      ]);
      final logs = results[0] as ({List<TwitchMsg> messages, String? error});
      if (!mounted) return;
      setState(() {
        _months = results[1] as List<TwitchMonth>;
        _msgs = logs.messages;
        if (logs.messages.isEmpty) {
          _error = logs.error ?? 'Nothing in this period.';
        }
      });
      // Emotes and badges arrive after the text, then the log repaints with them.
      final extras = await Future.wait([
        Api.twitchEmotes(channel).catchError((_) => <String, String>{}),
        Api.twitchBadges(channel).catchError((_) => <String, String>{}),
      ]);
      if (!mounted) return;
      setState(() {
        _emotes = extras[0];
        _badges = extras[1];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach the log service.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TwitchMsg> get _shown {
    final f = _find.text.trim().toLowerCase();
    final rows = f.isEmpty
        ? List<TwitchMsg>.from(_msgs)
        : _msgs.where((m) => m.text.toLowerCase().contains(f)).toList();
    rows.sort((a, b) => _oldestFirst ? a.ts.compareTo(b.ts) : b.ts.compareTo(a.ts));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final title = _openChannel == null
        ? 'Twitch logs'
        : '#${_openChannel!} · ${_user.text.trim()}';
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
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
        if (_openChannel == null) _searchBar() else _logBar(dark),
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
            suffixIcon:
                IconButton(icon: const Icon(Icons.search), onPressed: _findChannels),
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
              child: const Text('Go')),
        ]),
      ]),
    );
  }

  /// Month picker + find + sort, mirroring the public log viewers.
  Widget _logBar(bool dark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF17191C) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
          ),
          child: DropdownButton<String>(
            value: _period,
            underline: const SizedBox.shrink(),
            isDense: true,
            borderRadius: BorderRadius.circular(12),
            items: [
              const DropdownMenuItem(value: '', child: Text('All time')),
              for (final m in _months)
                DropdownMenuItem(value: m.label, child: Text(m.label)),
            ],
            onChanged: (v) => _openLogs(_openChannel!, period: v ?? ''),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _find,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Find…',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: _oldestFirst ? 'Oldest first' : 'Newest first',
          icon: Icon(_oldestFirst ? Icons.arrow_upward : Icons.arrow_downward,
              size: 20),
          onPressed: () => setState(() => _oldestFirst = !_oldestFirst),
        ),
      ]),
    );
  }

  Widget _body(bool dark) {
    if (_openChannel != null) return _logView(dark);

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

  /// One line per message: timestamp · badges · coloured name · text + emotes.
  Widget _logView(bool dark) {
    final rows = _shown;
    if (rows.isEmpty && !_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(_error ?? 'Nothing matches.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted(context))),
        ),
      );
    }
    final brightness = Theme.of(context).brightness;
    return ListView.builder(
      itemCount: rows.length + 1,
      itemBuilder: (c, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
            child: Text('${rows.length} message(s)',
                style: TextStyle(color: _muted(context), fontSize: 12)),
          );
        }
        final m = rows[i - 1];
        return InkWell(
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: m.text));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Copied'), duration: Duration(milliseconds: 800)));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                    fontSize: 13.5, height: 1.5, color: Theme.of(context).colorScheme.onSurface),
                children: [
                  TextSpan(
                    text: '${m.ts.replaceFirst('T', ' ').padRight(19).substring(0, 19)}  ',
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        color: _muted(context)),
                  ),
                  ...badgeSpans(m.badges, _badges),
                  TextSpan(
                    text: '${m.name}: ',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: nameColor(m, brightness)),
                  ),
                  ...messageSpans(m, _emotes),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
