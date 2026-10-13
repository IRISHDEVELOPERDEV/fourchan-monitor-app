import 'package:flutter_test/flutter_test.dart';
import 'package:fourchan_monitor/api.dart';
import 'package:fourchan_monitor/reply_browser.dart';

void main() {
  group('defensive JSON', () {
    test('Post tolerates missing and wrongly typed fields', () {
      final p = Post.fromJson({'no': '123', 'ts': 1.5, 'name': null, 'media': 5});
      expect(p.no, 123);
      expect(p.ts, 1);
      expect(p.name, 'Anonymous');
      expect(p.media, isNull);
      expect(p.hasMedia, isFalse);
    });

    test('Stats tolerates junk', () {
      final s = Stats.fromJson({
        'per_day': [
          {'date': '2026-10-01', 'count': 3},
          'junk',
        ],
        'per_hour': ['2', null],
        'per_term': {'EE': 4, 'Emily': 'x'},
      });
      expect(s.perDay.length, 2);
      expect(s.perDay.first.count, 3);
      expect(s.perHour, [2, 0]);
      expect(s.perTerm, {'EE': 4, 'Emily': 0});
    });
  });

  test('auth errors carry the rebuild message', () {
    expect(const AuthException(401).toString(), contains('Token rejected'));
  });

  group('reply browser allow-list', () {
    test('4chan domains allowed', () {
      for (final h in [
        'boards.4chan.org',
        'sys.4chan.org',
        '4chan.org',
        'www.4chan.org',
        'boards.4channel.org',
        'i.4cdn.org',
      ]) {
        expect(isAllowedBrowserHost(h), isTrue, reason: h);
      }
    });

    test('other domains blocked', () {
      for (final h in ['evil.com', '4chan.org.evil.com', 'not4chan.org', 'x4cdn.org']) {
        expect(isAllowedBrowserHost(h), isFalse, reason: h);
      }
    });

    test('text fill only on thread pages', () {
      expect(isFourchanThreadPage('https://boards.4chan.org/b/thread/123#p456'), isTrue);
      expect(isFourchanThreadPage('https://boards.4chan.org/b/'), isFalse);
      expect(isFourchanThreadPage('https://sys.4chan.org/auth'), isFalse);
      expect(isFourchanThreadPage('https://example.com/b/thread/1'), isFalse);
    });
  });
}
