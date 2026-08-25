import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'api.dart';

/// Renders a Twitch chat message with its emotes drawn as images.
///
/// Two sources are combined:
///  * Twitch's own emote tag (`id:start-end,...`) — covers sub/global emotes
///    and gives exact positions, so it wins where it applies.
///  * A name -> URL map of third-party emotes (7TV, BTTV, FFZ) matched on
///    whole words in whatever text is left.
class EmoteText extends StatelessWidget {
  final TwitchMsg msg;
  final Map<String, String> emotes;
  final TextStyle? style;
  const EmoteText(this.msg, this.emotes, {this.style, super.key});

  static const double _size = 26;

  Widget _img(String url) => CachedNetworkImage(
        imageUrl: url,
        height: _size,
        fit: BoxFit.contain,
        placeholder: (c, u) => const SizedBox(width: _size, height: _size),
        errorWidget: (c, u, e) => const SizedBox.shrink(),
      );

  InlineSpan _emoteSpan(String url) => WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: _img(url),
        ),
      );

  /// Twitch positions are code-point indices, so work in runes.
  List<({int start, int end, String id})> _twitchRanges() {
    final out = <({int start, int end, String id})>[];
    if (msg.emotes.isEmpty) return out;
    for (final part in msg.emotes.split('/')) {
      final i = part.indexOf(':');
      if (i <= 0) continue;
      final id = part.substring(0, i);
      for (final range in part.substring(i + 1).split(',')) {
        final d = range.split('-');
        if (d.length != 2) continue;
        final a = int.tryParse(d[0]);
        final b = int.tryParse(d[1]);
        if (a == null || b == null) continue;
        out.add((start: a, end: b, id: id));
      }
    }
    out.sort((x, y) => x.start.compareTo(y.start));
    return out;
  }

  /// Split plain text on spaces, swapping in third-party emotes by name.
  void _addWords(String text, List<InlineSpan> spans) {
    if (text.isEmpty) return;
    for (final word in text.split(' ')) {
      final url = emotes[word];
      if (url != null) {
        spans.add(_emoteSpan(url));
        spans.add(const TextSpan(text: ' '));
      } else {
        spans.add(TextSpan(text: '$word '));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final runes = msg.text.runes.toList();
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final r in _twitchRanges()) {
      if (r.start < cursor || r.start >= runes.length) continue;
      _addWords(String.fromCharCodes(runes.sublist(cursor, r.start)), spans);
      spans.add(_emoteSpan(
          'https://static-cdn.jtvnw.net/emoticons/v2/${r.id}/default/dark/2.0'));
      cursor = (r.end + 1).clamp(0, runes.length);
    }
    if (cursor < runes.length) {
      _addWords(String.fromCharCodes(runes.sublist(cursor)), spans);
    }

    return SelectableText.rich(TextSpan(style: style, children: spans));
  }
}
