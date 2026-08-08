import 'package:flutter/material.dart';
import 'api.dart';
import 'post_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _c = TextEditingController(text: 'Emily');
  List<Post> _results = [];
  bool _loading = false;
  String? _error;

  Future<void> _go() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _results = await Api.search(_c.text.trim());
    } catch (e) {
      _error = '$e';
      _results = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search archive')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _c,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _go(),
                decoration: const InputDecoration(
                    hintText: 'Search archived posts…', border: OutlineInputBorder()),
              ),
            ),
            IconButton(onPressed: _go, icon: const Icon(Icons.search)),
          ]),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(16), child: Text('Error: $_error')),
        Expanded(
          child: _results.isEmpty && !_loading
              ? const Center(child: Text('No results'))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (c, i) => PostCard(_results[i]),
                ),
        ),
      ]),
    );
  }
}
