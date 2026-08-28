import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'api.dart';

const double _emoteSize = 26;
const double _badgeSize = 18;

Widget _netImage(String url, double size) => CachedNetworkImage(
      imageUrl: url,
      height: size,
      fit: BoxFit.contain,
      placeholder: (c, u) => SizedBox(width: size, height: size),
      errorWidget: (c, u, e) => const SizedBox.shrink(),
    );

InlineSpan _imageSpan(String url, double size) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: _netImage(url, size),
      ),
    );

/// The chat badges (broadcaster, subscriber, verified…) that sit before a name.
List<InlineSpan> badgeSpans(String badges, Map<String, String> map) {
  final out = <InlineSpan>[];
  for (final b in badges.split(',')) {
    final url = map[b.trim()];
    if (url != null && url.isNotEmpty) out.add(_imageSpan(url, _badgeSize));
  }
  if (out.isNotEmpty) out.add(const TextSpan(text: ' '));
  return out;
}

/// A stable colour per name, for chatters who never picked a Twitch colour.
Color fallbackNameColor(String name, Brightness b) {
  var h = 0;
  for (final c in name.runes) {
    h = (h * 31 + c) % 360;
  }
  return HSLColor.fromAHSL(1, h.toDouble(), .70,
          b == Brightness.dark ? .68 : .38)
      .toColor();
}

Color nameColor(TwitchMsg m, Brightness b) {
  final c = m.color;
  if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(c)) {
    return Color(int.parse('FF${c.substring(1)}', radix: 16));
  }
  return fallbackNameColor(m.name, b);
}

/// The message body, with Twitch's own emotes placed at the exact positions it
/// gives us and third-party (7TV/BTTV/FFZ) emotes matched on whole words.
List<InlineSpan> messageSpans(TwitchMsg msg, Map<String, String> emotes) {
  final runes = msg.text.runes.toList();
  final spans = <InlineSpan>[];

  void addWords(String text) {
    if (text.isEmpty) return;
    for (final word in text.split(' ')) {
      final url = emotes[word];
      if (url != null) {
        spans.add(_imageSpan(url, _emoteSize));
        spans.add(const TextSpan(text: ' '));
      } else {
        spans.add(TextSpan(text: '$word '));
      }
    }
  }

  // Twitch positions are code-point indices, so work in runes.
  final ranges = <({int start, int end, String id})>[];
  for (final part in msg.emotes.split('/')) {
    final i = part.indexOf(':');
    if (i <= 0) continue;
    final id = part.substring(0, i);
    for (final range in part.substring(i + 1).split(',')) {
      final d = range.split('-');
      if (d.length != 2) continue;
      final a = int.tryParse(d[0]), b = int.tryParse(d[1]);
      if (a == null || b == null) continue;
      ranges.add((start: a, end: b, id: id));
    }
  }
  ranges.sort((x, y) => x.start.compareTo(y.start));

  var cursor = 0;
  for (final r in ranges) {
    if (r.start < cursor || r.start >= runes.length) continue;
    addWords(String.fromCharCodes(runes.sublist(cursor, r.start)));
    spans.add(_imageSpan(
        'https://static-cdn.jtvnw.net/emoticons/v2/${r.id}/default/dark/2.0',
        _emoteSize));
    cursor = (r.end + 1).clamp(0, runes.length);
  }
  if (cursor < runes.length) {
    addWords(String.fromCharCodes(runes.sublist(cursor)));
  }
  return spans;
}
