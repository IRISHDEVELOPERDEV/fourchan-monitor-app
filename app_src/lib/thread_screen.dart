import 'package:flutter/material.dart';
import 'api.dart';
import 'post_card.dart';

/// The full conversation around one post -- every reply in that thread, in
/// order, built from our own archive rather than fetched live from 4chan (so
/// it still works once 4chan has deleted the thread). Opens scrolled to the
/// post you came from, which is outlined so it's easy to find again.
class ThreadScreen extends StatefulWidget {
  final Post origin;
  /// From the Archive, posts are usually already gone from 4chan, so every
  /// card in this thread should link out to thebarchive too, same as the
  /// screen this was opened from.
  final bool archiveMode;
  const ThreadScreen(this.origin, {this.archiveMode = false, super.key});

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final _originKey = GlobalKey();
  final _scroll = ScrollController();
  List<Post>? _posts;
  String? _error;
  int _originIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final posts = await Api.thread(widget.origin.no);
      if (!mounted) return;
      final list = posts.isNotEmpty ? posts : [widget.origin];
      final idx = list.indexWhere((p) => p.no == widget.origin.no);
      setState(() {
        _posts = list;
        _originIndex = idx < 0 ? 0 : idx;
      });
      _scrollToOrigin();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  // ListView.builder only builds items near the viewport, so for a post deep
  // in a long thread the GlobalKey isn't attached to anything yet and
  // ensureVisible alone would silently do nothing. Jump to a rough estimate
  // first (based on an average card height) so the target post actually gets
  // built, then ensureVisible corrects to its exact position.
  static const _estimatedItemHeight = 150.0;
  void _scrollToOrigin() {
    if (_originIndex <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scroll.hasClients) return;
      final estimate = (_originIndex * _estimatedItemHeight)
          .clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.jumpTo(estimate);
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      final ctx = _originKey.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(ctx,
            alignment: 0.15, duration: const Duration(milliseconds: 250));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final board = widget.origin.board.isEmpty ? 'b' : widget.origin.board;
    return Scaffold(
      appBar: AppBar(
        title: Text(_posts == null
            ? 'Thread'
            : '/$board/ · ${_posts!.length} post${_posts!.length == 1 ? '' : 's'}'),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load the thread:\n$_error',
                    textAlign: TextAlign.center),
              ),
            )
          : _posts == null
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: _posts!.length,
                  itemBuilder: (context, i) {
                    final p = _posts![i];
                    final isOrigin = p.no == widget.origin.no;
                    final card = PostCard(p,
                        archiveMode: widget.archiveMode, highlighted: isOrigin);
                    return isOrigin ? KeyedSubtree(key: _originKey, child: card) : card;
                  },
                ),
    );
  }
}
