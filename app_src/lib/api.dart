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

/// App settings. The server URL and API token are fixed at build time (not
/// editable in the UI); everything else below is remembered per device.
class Config {
  // Server details are baked in (kept out of the Settings UI on purpose).
  static String baseUrl = 'http://2.24.129.131:8787';
  // Injected at build time from the MONITOR_API_TOKEN repo secret, so the
  // real key never sits in this public source tree.
  static String token = '__API_TOKEN__';
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
    // Older builds let you save a server URL and token in Settings. Those fields
    // are gone, so a stale saved token would silently override the current one
    // (and break the app the moment the old key is retired). Drop them.
    await p.remove('baseUrl');
    await p.remove('token');
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

  // External permanent /b/ archives (open in browser — they block in-app fetching).
  static String archiveThread(int thread, int no, {String board = 'b'}) {
    final b = board.isEmpty ? 'b' : board;   // /trash/ is watched too now
    return thread > 0
        ? 'https://thebarchive.com/$b/thread/$thread/#$no'
        : 'https://thebarchive.com/$b/post/$no/';
  }
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

  /// 4chan serves a small thumbnail beside every file ("1234s.jpg"), which is
  /// what a grid should load rather than the full-size image or video.
  /// Routed through our own server's /thumb cache rather than 4chan directly:
  /// the gallery can have dozens of these on screen at once, and unlike every
  /// other image in the app they'd otherwise never touch our fast, warm,
  /// server-side cache -- each device would cold-connect to 4chan for every
  /// tile, every time, which is what made the gallery feel slow.
  String? get thumb {
    final m = media;
    if (m == null || m.isEmpty) return null;
    final dot = m.lastIndexOf('.');
    final direct = dot <= 0 ? m : '${m.substring(0, dot)}s.jpg';
    return '${Config.baseUrl}/thumb?u=${Uri.encodeQueryComponent(direct)}';
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
  /// Twitch's own emote tag: "id:start-end,start-end/id2:start-end".
  final String emotes;
  /// Chat badges as "set/version" pairs, e.g. "broadcaster/1,subscriber/12".
  final String badges;
  /// The chatter's Twitch colour, e.g. "#F272EC" (may be empty).
  final String color;
  TwitchMsg.fromJson(Map<String, dynamic> j)
      : text = j['text'] ?? '',
        name = j['name'] ?? '',
        ts = j['ts'] ?? '',
        emotes = j['emotes'] ?? '',
        badges = j['badges'] ?? '',
        color = j['color'] ?? '',
        channel = j['channel'] ?? '';

}

class TwitchMonth {
  final int year, month;
  final String label;   // "2026-08"
  TwitchMonth.fromJson(Map<String, dynamic> j)
      : year = j['year'] ?? 0,
        month = j['month'] ?? 0,
        label = j['label'] ?? '';
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
      {int? before,
      int limit = 50,
      bool keywordsOnly = false,
      bool mediaOnly = false}) async {
    var u = '${Config.baseUrl}/feed?limit=$limit';
    if (before != null) u += '&before=$before';
    if (keywordsOnly) u += '&keywords=1';   // full EE/Emily stream, not client-filtered
    if (mediaOnly) u += '&media=1';         // gallery: only posts with a file
    final r = await http.get(Uri.parse(u), headers: _h).timeout(_t);
    if (r.statusCode != 200) throw Exception('feed HTTP ${r.statusCode}');
    return ((jsonDecode(r.body)['posts']) as List)
        .map((e) => Post.fromJson(e)).toList();
  }

  /// Every post we've archived from one thread, oldest first -- the full
  /// conversation around a given post, including context 4chan itself may have
  /// since deleted (served from our own DB, not fetched live from 4chan).
  static Future<List<Post>> thread(int postNo) async {
    final u = '${Config.baseUrl}/thread?no=$postNo';
    final r = await http.get(Uri.parse(u), headers: _h).timeout(_t);
    if (r.statusCode != 200) throw Exception('thread HTTP ${r.statusCode}');
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

  /// Emote name -> image URL for a channel (7TV, BTTV and FFZ, global + channel).
  static Future<Map<String, String>> twitchEmotes(String channel) async {
    final u = Uri.parse('${Config.baseUrl}/twitchemotes')
        .replace(queryParameters: {'channel': channel.trim()});
    final r = await http.get(u, headers: _h).timeout(const Duration(seconds: 40));
    if (r.statusCode != 200) return {};
    final e = (jsonDecode(r.body) as Map<String, dynamic>)['emotes'];
    return (e as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
  }

  /// Chat badge images ("set/version" -> url) for a channel.
  static Future<Map<String, String>> twitchBadges(String channel) async {
    final u = Uri.parse('${Config.baseUrl}/twitchbadges')
        .replace(queryParameters: {'channel': channel.trim()});
    final r = await http.get(u, headers: _h).timeout(const Duration(seconds: 40));
    if (r.statusCode != 200) return {};
    final b = (jsonDecode(r.body) as Map<String, dynamic>)['badges'];
    return (b as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
  }

  /// Months that have logs for this user in this channel, newest first.
  static Future<List<TwitchMonth>> twitchMonths(String channel, String user) async {
    final u = Uri.parse('${Config.baseUrl}/twitchmonths')
        .replace(queryParameters: {'channel': channel.trim(), 'user': user.trim()});
    final r = await http.get(u, headers: _h).timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) return [];
    return (((jsonDecode(r.body) as Map<String, dynamic>)['months'] ?? []) as List)
        .map((e) => TwitchMonth.fromJson(e as Map<String, dynamic>))
        .toList();
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
      String user, {String channel = '', String period = ''}) async {
    final params = <String, String>{'user': user.trim(), 'limit': '500'};
    if (channel.trim().isNotEmpty) params['channel'] = channel.trim();
    if (period.contains('-')) {
      final p = period.split('-');
      params['year'] = p[0];
      params['month'] = p[1];
    }
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
