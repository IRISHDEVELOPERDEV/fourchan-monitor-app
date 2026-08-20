import 'package:flutter/material.dart';
import 'api.dart';
import 'post_card.dart';

/// Opened when you tap an EE/Emily notification — shows that post inside the app.
class PostDetailScreen extends StatefulWidget {
  final int no;
  const PostDetailScreen({required this.no, super.key});
  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Post? _post;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await Api.post(widget.no);
      if (!mounted) return;
      setState(() {
        _post = p;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _post != null
              ? ListView(children: [PostCard(_post!)])
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error == null
                          ? "Couldn't find this post."
                          : "Couldn't load this post.",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
    );
  }
}
