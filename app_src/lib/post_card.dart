import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'api.dart';

class PostCard extends StatelessWidget {
  final Post post;
  const PostCard(this.post, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (post.isKeyword)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(post.matched,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              Expanded(
                child: Text('${post.name} · ${post.now} · No.${post.no}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              ),
            ]),
            const SizedBox(height: 6),
            if (post.hasMedia && post.isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: post.media!,
                  fit: BoxFit.cover,
                  placeholder: (c, u) => const SizedBox(
                      height: 120, child: Center(child: CircularProgressIndicator())),
                  errorWidget: (c, u, e) => const SizedBox(
                      height: 80, child: Center(child: Icon(Icons.broken_image))),
                ),
              ),
            if (post.hasMedia && post.isVideo) VideoTile(post.media!),
            if (post.com.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 6), child: SelectableText(post.com)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                // Open our server's PERMANENT copy of the post (never 404s), not the
                // ephemeral 4chan thread that gets deleted.
                onPressed: () => launchUrl(
                    Uri.parse('${Config.baseUrl}/p/${post.no}'),
                    mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open post'),
              ),
            ),
          ],
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
