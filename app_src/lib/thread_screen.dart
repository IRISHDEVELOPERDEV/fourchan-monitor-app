import 'package:flutter/material.dart';
import 'api.dart';
import 'post_card.dart';

/// The full conversation around one post -- every reply in that thread, in
/// order, built from our own archive rather than fetched live from 4chan (so
/// it still works once 4chan has deleted the thread). Opens scrolled to the
/// post you came from, which is outlined so it's easy to find again.
class ThreadScreen extends StatefulWidget {
  final Post origin;
  const ThreadScreen(this.origin, {super.key});

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final _originKey = GlobalKey();
  List<Post>? _posts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final posts = await Api.thread(widget.origin.no);
      if (!mounted) return;
      setState(() => _posts = posts.isNotEmpty ? posts : [widget.origin]);
      // Scroll to the post this was opened from, once its card exists.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _originKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
              alignment: 0.15, duration: const Duration(milliseconds: 300));
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
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
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: _posts!.length,
                  itemBuilder: (context, i) {
                    final p = _posts![i];
                    final isOrigin = p.no == widget.origin.no;
                    final card = PostCard(p, highlighted: isOrigin);
                    return isOrigin ? KeyedSubtree(key: _originKey, child: card) : card;
                  },
                ),
    );
  }
}
