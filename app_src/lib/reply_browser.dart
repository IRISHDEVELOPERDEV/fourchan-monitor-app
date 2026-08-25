import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as ext;
import 'package:webview_flutter/webview_flutter.dart';

/// 4chan's real site, inside the app. When you reply to a post we put the
/// >>quote (and your saved text, if you picked one) into 4chan's own reply box
/// and scroll to it — then you read it and press Post yourself. This never
/// submits for you. Log into your 4chan Pass once here (menu) and it sticks.
/// Route builder used with [Navigator.restorablePush] so the browser survives
/// Android tearing the app down while you switch away (e.g. to copy your Pass
/// token) — without this you get dropped back on the Feed.
@pragma('vm:entry-point')
Route<void> replyBrowserRoute(BuildContext context, Object? arguments) {
  final a = (arguments as Map).cast<String, Object?>();
  return MaterialPageRoute<void>(
    builder: (_) => ReplyBrowser(
      url: a['url'] as String,
      prefill: a['prefill'] as String?,
      quoteNo: a['quoteNo'] as int?,
      title: (a['title'] as String?) ?? 'Reply',
    ),
  );
}

class ReplyBrowser extends StatefulWidget {
  final String url;
  final String? prefill;
  final int? quoteNo; // post to quote; we insert >>no ourselves
  final String title;
  final bool showBack;
  const ReplyBrowser({
    required this.url,
    this.prefill,
    this.quoteNo,
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

  /// 4chan's own "#q" hash only works on the desktop layout, so we place the
  /// quote and text in the box ourselves and scroll it into view.
  Future<void> _fill() async {
    // Runs on every page load: the JS below skips text that's already there, so
    // leaving the app and coming back restores the quote instead of losing it.
    final no = widget.quoteNo;
    final text = widget.prefill ?? '';
    if (no == null && text.isEmpty) return;

    // Build the whole insertion in Dart so the injected JS needs no escaping.
    final buf = StringBuffer();
    if (no != null) buf.writeln('>>$no');
    if (text.isNotEmpty) buf.write(text);
    final add = jsonEncode(buf.toString());

    await _c.runJavaScript('''
(function(){
  var add = $add;
  var tries = 0;
  var timer = setInterval(function(){
    tries++;
    var ta = document.querySelector('#quickReply textarea[name="com"]')
          || document.querySelector('textarea[name="com"]');
    if (!ta) { if (tries > 80) { clearInterval(timer); } return; }
    clearInterval(timer);
    var cur = ta.value || '';
    if (cur.indexOf(add) === -1) {
      ta.value = cur + add;
      ta.dispatchEvent(new Event('input', {bubbles: true}));
    }
    try { ta.scrollIntoView({block: 'center'}); } catch (e) { }
    ta.focus();
    try { ta.setSelectionRange(ta.value.length, ta.value.length); } catch (e) { }
  }, 250);
})();
''');
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
