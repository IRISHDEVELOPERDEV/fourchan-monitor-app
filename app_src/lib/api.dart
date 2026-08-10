import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Bumped whenever the feed filter changes so the Feed screen rebuilds.
final ValueNotifier<int> feedRefresh = ValueNotifier<int>(0);

/// Persisted connection config (server URL + API token).
/// Pre-filled for testing so the app works immediately on install; a saved value
/// from Settings overrides these defaults.
class Config {
  static String baseUrl = 'http://2.24.129.131:8787';
  static String token = 'OkVPZPZzUNhe_ctMDkoOzJ_6vKKeyqwJ';
  static bool keywordsOnly = false;   // feed filter: show only EE/Emily posts

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final b = p.getString('baseUrl');
    if (b != null && b.isNotEmpty) baseUrl = b;
    final t = p.getString('token');
    if (t != null && t.isNotEmpty) token = t;
    keywordsOnly = p.getBool('keywordsOnly') ?? false;
  }

  static Future<void> setKeywordsOnly(bool v) async {
    keywordsOnly = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool('keywordsOnly', v);
    feedRefresh.value++;   // tell the Feed to re-filter
  }

  static Future<void> save(String url, String tok) async {
    final p = await SharedPreferences.getInstance();
    baseUrl = url.trim().replaceAll(RegExp(r'/$'), '');
    token = tok.trim();
    await p.setString('baseUrl', baseUrl);
    await p.setString('token', token);
  }
}

class Post {
  final int no;
  final String board;
  final int thread;
  final String name;
  final String now;
  final int ts;
  final String com;
  final String? ext;
  final String matched;
  final String url;
  final String? media;

  Post.fromJson(Map<String, dynamic> j)
      : no = j['no'] ?? 0,
        board = j['board'] ?? '',
        thread = j['thread'] ?? 0,
        name = j['name'] ?? 'Anonymous',
        now = j['now'] ?? '',
        ts = j['ts'] ?? 0,
        com = j['com'] ?? '',
        ext = j['ext'],
        matched = j['matched'] ?? '',
        url = j['url'] ?? '',
        media = j['media'];

  String get ago {
    if (ts == 0) return now;
    final d = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ts * 1000));
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  String get _e => (ext ?? '').toLowerCase();
  bool get hasMedia => media != null && media!.isNotEmpty;
  bool get isVideo => _e == '.webm' || _e == '.mp4';
  bool get isImage => ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(_e);
  bool get isKeyword => matched.isNotEmpty;
}

class Api {
  static Map<String, String> get _h => {'Authorization': 'Bearer ${Config.token}'};
  static const _t = Duration(seconds: 20);

  static Future<List<Post>> feed({int? before, int limit = 50}) async {
    var u = '${Config.baseUrl}/feed?limit=$limit';
    if (before != null) u += '&before=$before';
    final r = await http.get(Uri.parse(u), headers: _h).timeout(_t);
    if (r.statusCode != 200) throw Exception('feed HTTP ${r.statusCode}');
    return ((jsonDecode(r.body)['posts']) as List)
        .map((e) => Post.fromJson(e)).toList();
  }

  static Future<List<Post>> search(String q) async {
    final u = '${Config.baseUrl}/search?q=${Uri.encodeQueryComponent(q)}';
    final r = await http.get(Uri.parse(u), headers: _h).timeout(_t);
    if (r.statusCode != 200) throw Exception('search HTTP ${r.statusCode}');
    return ((jsonDecode(r.body)['posts']) as List)
        .map((e) => Post.fromJson(e)).toList();
  }

  static Future<bool> getVerbose() async {
    final r = await http.get(Uri.parse('${Config.baseUrl}/settings'), headers: _h).timeout(_t);
    return jsonDecode(r.body)['verbose'] == true;
  }

  static Future<bool> setVerbose(bool v) async {
    final r = await http.post(Uri.parse('${Config.baseUrl}/settings'),
        headers: {..._h, 'Content-Type': 'application/json'},
        body: jsonEncode({'verbose': v})).timeout(_t);
    return jsonDecode(r.body)['verbose'] == true;
  }

  static Future<Map<String, dynamic>> health() async {
    final r = await http.get(Uri.parse('${Config.baseUrl}/health'), headers: _h).timeout(_t);
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<void> registerDevice(String fcmToken) async {
    try {
      await http.post(Uri.parse('${Config.baseUrl}/devices'),
          headers: {..._h, 'Content-Type': 'application/json'},
          body: jsonEncode({'token': fcmToken})).timeout(_t);
    } catch (_) {/* best effort */}
  }
}
