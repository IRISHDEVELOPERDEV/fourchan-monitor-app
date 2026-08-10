import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';
import 'post_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final List<Post> _posts = [];
  final _scroll = ScrollController();
  bool _loading = false;
  bool _end = false;
  String? _error;
  Timer? _live;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 500) _load();
    });
    // Live updates: pull any newer posts every 5s and slot them in at the top.
    _live = Timer.periodic(const Duration(seconds: 5), (_) => _pollNew());
  }

  @override
  void dispose() {
    _live?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pollNew() async {
    if (_loading || _posts.isEmpty) return;
    try {
      final latest = await Api.feed(limit: 30);
      final topNo = _posts.first.no;
      final fresh = latest.where((p) => p.no > topNo).toList();
      if (fresh.isNotEmpty && mounted) {
        setState(() => _posts.insertAll(0, fresh));
      }
    } catch (_) {/* ignore transient poll errors */}
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
      final batch = await Api.feed(before: before);
      setState(() {
        if (refresh) _posts.clear();
        _posts.addAll(batch);
        if (batch.isEmpty) _end = true;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: (_posts.isEmpty && _error != null)
            ? ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load feed:\n$_error\n\n'
                    'Open Settings and set your server URL + API token.',
                  ),
                ),
              ])
            : ListView.builder(
                controller: _scroll,
                itemCount: _posts.length + 1,
                itemBuilder: (c, i) {
                  if (i >= _posts.length) {
                    return _loading
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()))
                        : const SizedBox(height: 48);
                  }
                  return PostCard(_posts[i]);
                },
              ),
      ),
    );
  }
}
