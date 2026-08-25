import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as ext;
import 'package:webview_flutter/webview_flutter.dart';

/// 4chan's real site, inside the app, with your saved reply already typed into
/// the reply box. You read it and press Post yourself — this never submits for
/// you. Log into your 4chan Pass once here (menu) and it sticks, so no captcha.
class ReplyBrowser extends StatefulWidget {
  final String url;
  final String? prefill;
  final String title;
  final bool showBack;
  const ReplyBrowser({
    required this.url,
    this.prefill,
    this.title = 'Reply',
    this.showBack = true,
    super.key,
  });

  @override
  State<ReplyBrowser> createState() => _ReplyBrowserState();
}

class _ReplyBrowserState extends State<ReplyBrowser> {
  late final WebViewController _c;
  bool _loading = true;
  bool _filled = false;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
          _fill();
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  /// Drop the text into 4chan's own reply box, keeping the >>quote it inserted.
  /// Deliberately does NOT click Post.
  Future<void> _fill() async {
    final text = widget.prefill;
    if (text == null || text.isEmpty || _filled) return;
    final t = jsonEncode(text); // safely quoted JS string
    await _c.runJavaScript('''
(function(){
  var tries = 0;
  var timer = setInterval(function(){
    tries++;
    var ta = document.querySelector('#quickReply textarea[name="com"]')
          || document.querySelector('textarea[name="com"]');
    if (ta) {
      clearInterval(timer);
      var cur = ta.value || '';
      var add = $t;
      if (cur.indexOf(add) === -1) {
        ta.value = cur + ((cur && !/\n\$/.test(cur)) ? '\n' : '') + add;
        ta.dispatchEvent(new Event('input', {bubbles:true}));
      }
      ta.focus();
    } else if (tries > 60) { clearInterval(timer); }
  }, 250);
})();
''');
    _filled = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBack,
        title: Text(widget.title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'pass') {
                _c.loadRequest(Uri.parse('https://sys.4chan.org/auth'));
              } else if (v == 'reload') {
                _filled = false;
                _c.reload();
              } else if (v == 'external') {
                ext.launchUrl(Uri.parse(widget.url),
                    mode: ext.LaunchMode.externalApplication);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pass', child: Text('Log in to 4chan Pass')),
              PopupMenuItem(value: 'reload', child: Text('Reload')),
              PopupMenuItem(value: 'external', child: Text('Open in browser')),
            ],
          ),
        ],
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: WebViewWidget(controller: _c),
    );
  }
}
