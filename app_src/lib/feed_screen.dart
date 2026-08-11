import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';
import 'post_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with WidgetsBindingObserver {
  static const _green = Color(0xFF43B14B);
  final List<Post> _posts = [];
  final _scroll = ScrollController();
  bool _paging = false;    // loading OLDER pages (pagination) — must not block live refresh
  bool _polling = false;   // fetching NEWEST posts (the 2s live refresh)
  bool _end = false;
  int _autoLoads = 0;      // caps the auto-load cascade so it can never run away
  String? _error;
  Timer? _live;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load(refresh: true);
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 500) _load();
    });
    // Live updates: pull any newer posts every 2s and slot them in at the top.
    // Runs independently of pagination so it NEVER stalls.
    _live = Timer.periodic(const Duration(seconds: 2), (_) => _pollNew());
    feedRefresh.addListener(_onFilterChanged);   // re-filter when the toggle flips
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reopening the app shows fresh posts immediately instead of waiting a tick.
    if (state == AppLifecycleState.resumed) _pollNew();
  }

  void _onFilterChanged() {
    if (mounted) setState(() {});
    _autoLoads = 0;      // allow a fresh top-up for the new filter
    _maybeAutoLoad();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    feedRefresh.removeListener(_onFilterChanged);
    _live?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  int get _shownCount =>
      Config.keywordsOnly ? _posts.where((p) => p.isKeyword).length : _posts.length;

  /// When the EE/Emily filter hides most posts the visible list can be too short
  /// to scroll (which is what triggers pagination), so fetch a few more pages —
  /// but capped, so it can't loop through the whole archive and block refresh.
  void _maybeAutoLoad() {
    if (!mounted || _paging || _end) return;
    if (_shownCount < 8 && _autoLoads < 5) {
      _autoLoads++;
      _load();
    }
  }

  /// Fetch the newest posts and slot any we don't have yet at the top.
  /// Guarded ONLY by its own flag — pagination can never block it.
  Future<void> _pollNew() async {
    if (_polling || _posts.isEmpty) return;
    _polling = true;
    try {
      final latest = await Api.feed(limit: 30);
      final topNo = _posts.first.no;
      final fresh = latest.where((p) => p.no > topNo).toList();
      if (fresh.isNotEmpty && mounted) {
        setState(() => _posts.insertAll(0, fresh));
      }
    } catch (_) {/* ignore transient poll errors */} finally {
      _polling = false;
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (_paging || (_end && !refresh)) return;
    setState(() {
      _paging = true;
      if (refresh) {
        _error = null;
        _end = false;
        _autoLoads = 0;
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
      if (mounted) setState(() => _paging = false);
      _maybeAutoLoad();
    }
  }

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<bool>(
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            backgroundColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected) ? _green : const Color(0xFF17191C)),
            foregroundColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected) ? Colors.black : Colors.grey.shade300),
          ),
          segments: const [
            ButtonSegment(
                value: false,
                label: Text('All'),
                icon: Icon(Icons.forum_outlined, size: 16)),
            ButtonSegment(
                value: true,
                label: Text('EE / Emily'),
                icon: Icon(Icons.star_rounded, size: 16)),
          ],
          selected: {Config.keywordsOnly},
          onSelectionChanged: (s) => Config.setKeywordsOnly(s.first),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: Column(
        children: [
          _filterBar(),
          Expanded(
            child: RefreshIndicator(
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
                  : Builder(builder: (context) {
                      final shown = Config.keywordsOnly
                          ? _posts.where((p) => p.isKeyword).toList()
                          : _posts;
                      if (shown.isEmpty && !_paging) {
                        return ListView(children: [
                          Padding(
                            padding: const EdgeInsets.all(40),
                            child: Center(
                                child: Text(
                                    Config.keywordsOnly
                                        ? 'No EE/Emily posts yet.\nPull down to refresh.'
                                        : 'No posts yet.\nPull down to refresh.',
                                    textAlign: TextAlign.center)),
                          ),
                        ]);
                      }
                      return ListView.builder(
                        controller: _scroll,
                        itemCount: shown.length + 1,
                        itemBuilder: (c, i) {
                          if (i >= shown.length) {
                            return _paging
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(child: CircularProgressIndicator()))
                                : const SizedBox(height: 48);
                          }
                          return PostCard(shown[i]);
                        },
                      );
                    }),
            ),
          ),
        ],
      ),
    );
  }
}
