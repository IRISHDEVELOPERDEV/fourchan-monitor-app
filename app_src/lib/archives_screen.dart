import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'post_card.dart';

/// In-app archive browser over OUR saved posts: look up a name and see the
/// results (text + images + video) right here, with year / media filters.
/// External archives (thebarchive etc.) block in-app fetching, so those are
/// offered as "open in browser" options.
class ArchivesScreen extends StatefulWidget {
  const ArchivesScreen({super.key});
  @override
  State<ArchivesScreen> createState() => _ArchivesScreenState();
}

class _ArchivesScreenState extends State<ArchivesScreen> {
  static const _green = Color(0xFF43B14B);
  final _c = TextEditingController(text: 'EE');
  int? _year; // null = all years
  bool _mediaOnly = false;
  bool _oldestFirst = false;
  List<Post> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  List<int> _years = []; // only years that actually have data (from the server)

  @override
  void initState() {
    super.initState();
    _loadYears();
    // Run an initial search so the tab shows results immediately (feels connected).
    WidgetsBinding.instance.addPostFrameCallback((_) => _go());
  }

  Future<void> _loadYears() async {
    try {
      final ys = await Api.years();
      if (mounted) setState(() => _years = ys);
    } catch (_) {/* leave empty -> only "All years" is offered */}
  }

  Future<void> _go() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });
    try {
      _results = await Api.searchAdvanced(
        q: _c.text.trim(),
        year: _year,
        mediaOnly: _mediaOnly,
        oldestFirst: _oldestFirst,
      );
    } catch (e) {
      _error = '$e';
      _results = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _externalSheet() {
    final q = _c.text.trim();
    showModalBottomSheet(
      context: context,
      backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF17191C) : Colors.white),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Open "$q" in a full external archive',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new, color: _green),
            title: const Text('thebarchive.com'),
            subtitle: const Text('Full /b/ archive · full-size images'),
            onTap: () { Navigator.pop(context); _open(Config.thebarchiveSearch(q)); },
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new, color: _green),
            title: const Text('archived.moe'),
            subtitle: const Text('Every board incl. /b/ · thumbnails'),
            onTap: () { Navigator.pop(context); _open(Config.archivedMoeSearch(q)); },
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new, color: _green),
            title: const Text('RandomArchive.com'),
            subtitle: const Text('Custom /b/ archive · via Google'),
            onTap: () { Navigator.pop(context); _open(Config.randomArchiveSearch(q)); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archive')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _c,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _go(),
                decoration: const InputDecoration(
                  hintText: 'Look up a name…',
                  prefixIcon: Icon(Icons.person_search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            FilledButton(onPressed: _go, child: const Text('Search')),
          ]),
        ),
        // Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            _yearDropdown(),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Media only'),
              selected: _mediaOnly,
              onSelected: (v) { setState(() => _mediaOnly = v); _go(); },
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text(_oldestFirst ? 'Oldest first' : 'Newest first'),
              selected: _oldestFirst,
              onSelected: (v) { setState(() => _oldestFirst = v); _go(); },
            ),
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.travel_explore, size: 18),
              label: const Text('Full archives'),
              onPressed: _externalSheet,
            ),
          ]),
        ),
        const SizedBox(height: 4),
        if (_loading) const LinearProgressIndicator(),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _yearDropdown() {
    return DropdownButton<int?>(
      value: _year,
      hint: const Text('All years'),
      underline: const SizedBox.shrink(),
      dropdownColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF17191C) : Colors.white),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('All years')),
        for (final y in _years)
          DropdownMenuItem<int?>(value: y, child: Text('$y')),
      ],
      onChanged: (v) { setState(() => _year = v); _go(); },
    );
  }

  Widget _body() {
    if (_error != null) {
      return ListView(children: [
        Padding(padding: const EdgeInsets.all(24), child: Text('Error: $_error')),
      ]);
    }
    if (!_searched) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Search our archive by name.\nUse "Full archives" to open the\n'
              'complete external archives in your browser.',
              textAlign: TextAlign.center),
        ),
      );
    }
    if (_results.isEmpty && !_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Nothing in our archive for that.',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _externalSheet,
              icon: const Icon(Icons.travel_explore, size: 18),
              label: const Text('Try the full external archives'),
            ),
          ]),
        ),
      );
    }
    return ListView.builder(
      itemCount: _results.length + 1,
      itemBuilder: (c, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
            child: Text('${_results.length} result(s) in our archive',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          );
        }
        return PostCard(_results[i - 1], archiveMode: true);
      },
    );
  }
}
