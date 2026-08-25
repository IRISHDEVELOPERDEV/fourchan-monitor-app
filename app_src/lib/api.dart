import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Bumped whenever the feed filter changes so the Feed screen rebuilds.
final ValueNotifier<int> feedRefresh = ValueNotifier<int>(0);

/// Drives the app's light/dark/system theme (Settings updates this live).
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

/// This device's FCM token (set once push is initialised) so the Notifications
/// switch can register/unregister it for push.
String? fcmToken;

/// App-wide navigator so a tapped notification can open a post IN the app.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Persisted connection config (server URL + API token).
/// Pre-filled for testing so the app works immediately on install; a saved value
/// from Settings overrides these defaults.
class Config {
  // Server details are baked in (kept out of the Settings UI on purpose).
  static String baseUrl = 'http://2.24.129.131:8787';
  static String token = 'OkVPZPZzUNhe_ctMDkoOzJ_6vKKeyqwJ';
  static bool keywordsOnly = false;   // feed filter: show only EE/Emily posts
  static bool notificationsEnabled = true;  // push EE/Emily alerts to this phone
  static ThemeMode themeMode = ThemeMode.dark;
  static List<String> savedReplies = [];  // your own canned replies (copy+paste)

  static ThemeMode _parseTheme(String? s) => s == 'light'
      ? ThemeMode.light
      : s == 'system'
          ? ThemeMode.system
          : ThemeMode.dark;
  static String _themeName(ThemeMode m) => m == ThemeMode.light
      ? 'light'
      : m == ThemeMode.system
          ? 'system'
          : 'dark';

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final b = p.getString('baseUrl');
    if (b != null && b.isNotEmpty) baseUrl = b;
    final t = p.getString('token');
    if (t != null && t.isNotEmpty) token = t;
    keywordsOnly = p.getBool('keywordsOnly') ?? false;
    notificationsEnabled = p.getBool('notificationsEnabled') ?? true;
    savedReplies = p.getStringList('savedReplies') ?? [];
    themeMode = _parseTheme(p.getString('themeMode'));
    themeNotifier.value = themeMode;
  }

  static Future<void> setNotificationsEnabled(bool v) async {
    notificationsEnabled = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool('notificationsEnabled', v);
  }

  static Future<void> setKeywordsOnly(bool v) async {
    keywordsOnly = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool('keywordsOnly', v);
    feedRefresh.value++;   // tell the Feed to re-filter
  }

  static Future<void> setSavedReplies(List<String> v) async {
    savedReplies = v;
    final p = await SharedPreferences.getInstance();
    await p.setStringList('savedReplies', v);
  }

  static Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    themeNotifier.value = m;   // update the app's theme live
    final p = await SharedPreferences.getInstance();
    await p.setString('themeMode', _themeName(m));
  }

  static Future<void> save(String url, String tok) async {
    final p = await SharedPreferences.getInstance();
    baseUrl = url.trim().replaceAll(RegExp(r'/$'), '');
    token = tok.trim();
    await p.setString('baseUrl', baseUrl);
    await p.setString('token', token);
  }

  // Opens the live 4chan thread with the quick-reply box already quoting this
  // post (#q<no>), so you reply in your own logged-in browser session. We never
  // post on your behalf: 4chan requires a captcha and third-party posting
  // clients break their rules (and risk your Pass).
  static String replyUrl(String board, int thread, int no) =>
      'https://boards.4chan.org/${board.isEmpty ? 'b' : board}/thread/$thread#q$no';

  // External permanent /b/ archives (open in browser — they block in-app fetching).
  static String archiveThread(int thread, int no) => thread > 0
      ? 'https://thebarchive.com/b/thread/$thread/#$no'
      : 'https://thebarchive.com/b/post/$no/';
  static String thebarchiveSearch(String q) =>
      'https://thebarchive.com/b/search/text/${Uri.encodeComponent(q.trim())}/';
  static String archivedMoeSearch(String q) =>
      'https://archived.moe/b/search/text/${Uri.encodeComponent(q.trim())}/';
  static String randomArchiveSearch(String q) =>
      'https://www.google.com/search?q=${Uri.encodeComponent('site:randomarchive.com ${q.trim()}')}';
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

class TwitchMsg {
  final String text;
  final String name;
  final String ts;
  final String channel;
  TwitchMsg.fromJson(Map<String, dynamic> j)
      : text = j['text'] ?? '',
        name = j['name'] ?? '',
        ts = j['ts'] ?? '',
        channel = j['channel'] ?? '';

  /// "2026-08-15 20:45" from the ISO timestamp.
  String get when {
    if (ts.length < 16) return ts;
    return '${ts.substring(0, 10)} ${ts.substring(11, 16)}';
  }
}

class TwitchChannelHit {
  final String channel;
  final int count;
  final String last;
  TwitchChannelHit.fromJson(Map<String, dynamic> j)
      : channel = j['channel'] ?? '',
        count = j['count'] ?? 0,
        last = j['last'] ?? '';
  String get lastDay => last.length >= 10 ? last.substring(0, 10) : last;
}

class Api {
  static Map<String, String> get _h => {'Authorization': 'Bearer ${Config.token}'};
  static const _t = Duration(seconds: 20);

  static Future<List<Post>> feed(
      {int? before, int limit = 50, bool keywordsOnly = false}) async {
    var u = '${Config.baseUrl}/feed?limit=$limit';
    if (before != null) u += '&before=$before';
    if (keywordsOnly) u += '&keywords=1';   // full EE/Emily stream, not client-filtered
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

  /// Search OUR archive with filters (year, media-only, sort order).
  static Future<List<Post>> searchAdvanced({
    String q = '',
    int? year,
    bool mediaOnly = false,
    bool oldestFirst = false,
    int limit = 200,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'order': oldestFirst ? 'asc' : 'desc',
    };
    if (q.isNotEmpty) params['q'] = q;
    if (year != null) params['year'] = '$year';
    if (mediaOnly) params['media'] = '1';
    final u = Uri.parse('${Config.baseUrl}/search')
        .replace(queryParameters: params);
    final r = await http.get(u, headers: _h).timeout(_t);
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

  /// Which channels this user actually appears in (newest activity first).
  static Future<List<TwitchChannelHit>> twitchUserChannels(String user) async {
    final u = Uri.parse('${Config.baseUrl}/twitchuserchannels')
        .replace(queryParameters: {'user': user.trim()});
    final r = await http.get(u, headers: _h).timeout(const Duration(seconds: 60));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    return (((jsonDecode(r.body) as Map<String, dynamic>)['results'] ?? []) as List)
        .map((e) => TwitchChannelHit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Twitch chat logs: what [user] said, optionally narrowed to one [channel].
  /// With no channel it searches the main OTK-adjacent channels.
  static Future<({List<TwitchMsg> messages, String? error})> twitchLogs(
      String user, {String channel = ''}) async {
    final params = <String, String>{'user': user.trim(), 'limit': '200'};
    if (channel.trim().isNotEmpty) params['channel'] = channel.trim();
    final u = Uri.parse('${Config.baseUrl}/twitchlogs')
        .replace(queryParameters: params);
    final r = await http.get(u, headers: _h).timeout(const Duration(seconds: 40));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final msgs = ((j['messages'] ?? []) as List)
        .map((e) => TwitchMsg.fromJson(e as Map<String, dynamic>))
        .toList();
    return (messages: msgs, error: j['error'] as String?);
  }

  /// Fetch a single archived post by number (for the notification deep-link).
  static Future<Post?> post(int no) async {
    final r = await http.get(Uri.parse('${Config.baseUrl}/post?no=$no'),
        headers: _h).timeout(_t);
    if (r.statusCode != 200) return null;
    final j = jsonDecode(r.body)['post'];
    return j == null ? null : Post.fromJson(j as Map<String, dynamic>);
  }

  /// Years that actually have data in our archive (newest first).
  static Future<List<int>> years() async {
    final r = await http.get(Uri.parse('${Config.baseUrl}/years'), headers: _h)
        .timeout(_t);
    if (r.statusCode != 200) return [];
    return ((jsonDecode(r.body)['years']) as List)
        .map((e) => (e as num).toInt()).toList();
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

  static Future<void> unregisterDevice(String fcmToken) async {
    try {
      await http.post(Uri.parse('${Config.baseUrl}/devices'),
          headers: {..._h, 'Content-Type': 'application/json'},
          body: jsonEncode({'token': fcmToken, 'remove': true})).timeout(_t);
    } catch (_) {/* best effort */}
  }
}
