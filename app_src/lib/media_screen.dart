import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'api.dart';
import 'post_detail_screen.dart';

/// Every image and video from the watched threads, as a grid. Tapping one opens
/// the post it came from, so you get the text and the usual actions with it.
class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});
  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  static const _green = Color(0xFF43B14B);
  final List<Post> _posts = [];
  final _scroll = ScrollController();
  bool _loading = false;
  bool _end = false;
  bool _keywordsOnly = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading || (_end && !refresh)) return;
    setState(() {
      _loading = true;
      if (refresh) {
        _error = null;
        _end = false;
      }
    });
    try {
      final before = (refresh || _posts.isEmpty) ? null : _posts.last.no;
      final batch = await Api.feed(
        before: before,
        limit: 60,
        mediaOnly: true,
        keywordsOnly: _keywordsOnly,
      );
      if (!mounted) return;
      setState(() {
        if (refresh) _posts.clear();
        _posts.addAll(batch);
        if (batch.isEmpty) _end = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setFilter(bool kw) {
    setState(() => _keywordsOnly = kw);
    _load(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final unselBg = dark ? const Color(0xFF17191C) : const Color(0xFFECEEF1);
    final unselFg = Theme.of(context).colorScheme.onSurface.withOpacity(0.75);
    // Wider screens simply fit more columns.
    final width = MediaQuery.of(context).size.width;
    final columns = width > 700 ? 4 : (width > 480 ? 3 : 2);

    return Scaffold(
      appBar: AppBar(title: const Text('Media')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                backgroundColor: WidgetStateProperty.resolveWith((s) =>
                    s.contains(WidgetState.selected) ? _green : unselBg),
                foregroundColor: WidgetStateProperty.resolveWith((s) =>
                    s.contains(WidgetState.selected) ? Colors.black : unselFg),
              ),
              segments: const [
                ButtonSegment(
                    value: false,
                    label: Text('All'),
                    icon: Icon(Icons.photo_library_outlined, size: 16)),
                ButtonSegment(
                    value: true,
                    label: Text('EE / Emily'),
                    icon: Icon(Icons.star_rounded, size: 16)),
              ],
              selected: {_keywordsOnly},
              onSelectionChanged: (s) => _setFilter(s.first),
            ),
          ),
        ),
        if (_loading && _posts.isEmpty) const LinearProgressIndicator(),
        Expanded(child: _grid(columns)),
      ]),
    );
  }

  Widget _grid(int columns) {
    if (_posts.isEmpty && _error != null) {
      return ListView(children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load media:\n$_error', textAlign: TextAlign.center),
        ),
      ]);
    }
    if (_posts.isEmpty && !_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _keywordsOnly
                ? 'No EE/Emily images or videos yet.'
                : 'No media yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: GridView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(6),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemCount: _posts.length + (_loading ? 1 : 0),
        itemBuilder: (c, i) {
          if (i >= _posts.length) {
            return const Center(child: CircularProgressIndicator());
          }
          return _tile(_posts[i]);
        },
      ),
    );
  }

  Widget _tile(Post p) {
    final thumb = p.thumb;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PostDetailScreen(no: p.no))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumb != null)
              CachedNetworkImage(
                imageUrl: thumb,
                fit: BoxFit.cover,
                placeholder: (c, u) => Container(color: Colors.black26),
                errorWidget: (c, u, e) => Container(
                  color: Colors.black26,
                  child: const Icon(Icons.broken_image, size: 20),
                ),
              )
            else
              Container(color: Colors.black26),
            // Videos get a play badge so you know before tapping.
            if (p.isVideo)
              const Positioned(
                right: 4,
                bottom: 4,
                child: Icon(Icons.play_circle_fill,
                    size: 26, color: Colors.white70),
              ),
            if (p.isKeyword)
              Positioned(
                left: 4,
                top: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: _green, borderRadius: BorderRadius.circular(20)),
                  child: Text(p.matched,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
