import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'api.dart';

class PostCard extends StatelessWidget {
  final Post post;
  const PostCard(this.post, {super.key});

  static const _green = Color(0xFF43B14B);
  static const _quoteColor = Color(0xFF6AA9C9);
  // Highlights >>post quote-links and the watched names so gossip is scannable.
  static final RegExp _bodyPattern =
      RegExp(r'>>\d+|\b(?:EE|Emily)\b', caseSensitive: false);

  List<TextSpan> _bodySpans(String text) {
    final spans = <TextSpan>[];
    int last = 0;
    for (final m in _bodyPattern.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final tok = m.group(0)!;
      spans.add(tok.startsWith('>>')
          ? TextSpan(text: tok, style: const TextStyle(color: _quoteColor))
          : TextSpan(
              text: tok,
              style: const TextStyle(color: _green, fontWeight: FontWeight.bold)));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: post.com));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Post copied'), duration: Duration(milliseconds: 900)));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _copy(context),   // long-press anywhere to copy the post
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF17191C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: post.isKeyword ? _green.withOpacity(0.55) : Colors.white.withOpacity(0.06),
          width: post.isKeyword ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: _green.withOpacity(0.18),
              child: const Text('A',
                  style: TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('${post.ago} · No.${post.no}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            if (post.isKeyword)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                    color: _green, borderRadius: BorderRadius.circular(20)),
                child: Text(post.matched,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
              ),
          ]),
          if (post.hasMedia && post.isImage) ...[
            const SizedBox(height: 10),
            GestureDetector(
              // Tap to open fullscreen with pinch-to-zoom.
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => _FullscreenImage(post.media!))),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CachedNetworkImage(
                      imageUrl: post.media!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (c, u) => Container(
                          height: 160,
                          color: Colors.black26,
                          child: const Center(child: CircularProgressIndicator())),
                      errorWidget: (c, u, e) => Container(
                          height: 80,
                          color: Colors.black26,
                          child: const Center(child: Icon(Icons.broken_image))),
                    ),
                    Container(
                      margin: const EdgeInsets.all(6),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.zoom_out_map,
                          size: 16, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (post.hasMedia && post.isVideo) ...[
            const SizedBox(height: 10),
            VideoTile(post.media!),
          ],
          if (post.com.isNotEmpty) ...[
            const SizedBox(height: 10),
            SelectableText.rich(
              TextSpan(
                style: const TextStyle(
                    fontSize: 14.5, height: 1.4, color: Color(0xFFEAEAEA)),
                children: _bodySpans(post.com),
              ),
            ),
          ],
          Row(
            children: [
              // Copy the post text (also available by long-pressing the card).
              TextButton.icon(
                style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade500,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 34)),
                onPressed: () => _copy(context),
                icon: const Icon(Icons.copy, size: 15),
                label: const Text('Copy'),
              ),
              const Spacer(),
              // "Archive" = the full permanent thread on thebarchive.com — works
              // after 4chan deletes it, with the whole conversation.
              TextButton.icon(
                style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade500,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 34)),
                onPressed: () => launchUrl(
                    Uri.parse(Config.archiveThread(post.thread, post.no)),
                    mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.archive_outlined, size: 15),
                label: const Text('Archive'),
              ),
              // "Open" = the LIVE 4chan thread (what the user wants by default).
              TextButton.icon(
                style: TextButton.styleFrom(
                    foregroundColor: _green,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 34)),
                onPressed: () => launchUrl(
                    Uri.parse(post.url.isNotEmpty
                        ? post.url
                        : '${Config.baseUrl}/p/${post.no}'),
                    mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new, size: 15),
                label: const Text('Open'),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

/// Fullscreen, pinch-to-zoom image view (tap image in a card to open).
class _FullscreenImage extends StatelessWidget {
  final String url;
  const _FullscreenImage(this.url);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (c, u) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (c, u, e) =>
                const Icon(Icons.broken_image, color: Colors.white54, size: 64),
          ),
        ),
      ),
    );
  }
}

/// Tap-to-play video (ExoPlayer supports .webm natively on Android).
class VideoTile extends StatefulWidget {
  final String url;
  const VideoTile(this.url, {super.key});
  @override
  State<VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends State<VideoTile> {
  VideoPlayerController? _c;
  bool _loading = false;

  Future<void> _play() async {
    setState(() => _loading = true);
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await c.initialize();
      await c.setLooping(true);
      await c.play();
      setState(() => _c = c);
    } catch (_) {
      // leave placeholder on failure
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c != null && c.value.isInitialized) {
      return GestureDetector(
        onTap: () => setState(() => c.value.isPlaying ? c.pause() : c.play()),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
        ),
      );
    }
    return GestureDetector(
      onTap: _loading ? null : _play,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
            color: Colors.black26, borderRadius: BorderRadius.circular(6)),
        child: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : const Icon(Icons.play_circle_fill, size: 56),
        ),
      ),
    );
  }
}
