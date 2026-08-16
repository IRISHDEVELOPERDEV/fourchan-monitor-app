import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A place to look up any name across every archive that keeps /b/.
/// Type a name and jump straight into each archive's own search.
class ArchivesScreen extends StatefulWidget {
  const ArchivesScreen({super.key});
  @override
  State<ArchivesScreen> createState() => _ArchivesScreenState();
}

class _Archive {
  final String name;
  final String desc;
  final String Function(String q) url;
  const _Archive(this.name, this.desc, this.url);
}

String _enc(String q) => Uri.encodeComponent(q.trim());

final List<_Archive> _archives = [
  _Archive('thebarchive.com', 'Dedicated /b/ archive · full-size images',
      (q) => 'https://thebarchive.com/b/search/text/${_enc(q)}/'),
  _Archive('archived.moe', 'Every board incl. /b/ · thumbnails only',
      (q) => 'https://archived.moe/b/search/text/${_enc(q)}/'),
  _Archive('RandomArchive.com', 'Custom /b/ archive · via Google',
      (q) => 'https://www.google.com/search?q=${_enc('site:randomarchive.com $q')}'),
];

class _ArchivesScreenState extends State<ArchivesScreen> {
  static const _green = Color(0xFF43B14B);
  final _c = TextEditingController(text: 'EE');

  void _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archives')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            controller: _c,
            textInputAction: TextInputAction.search,
            onSubmitted: (q) {
              if (q.trim().isNotEmpty) _open(_archives.first.url(q)); // Enter = thebarchive
            },
            decoration: const InputDecoration(
              labelText: 'Name to look up',
              hintText: 'e.g. EE, Emily, a streamer…',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_search),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Search this name across every /b/ archive:',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final a in _archives)
                Card(
                  color: const Color(0xFF17191C),
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: ListTile(
                    leading: const Icon(Icons.archive_outlined, color: _green),
                    title: Text(a.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(a.desc),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () {
                      final q = _c.text.trim();
                      if (q.isNotEmpty) _open(a.url(q));
                    },
                  ),
                ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  'Opens each archive\'s own search in your browser. /b/ is only kept by '
                  'these few sites, so this covers everything that\'s archived.',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
