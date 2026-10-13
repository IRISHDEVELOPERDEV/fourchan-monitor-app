import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'api.dart';
import 'retry_button.dart';

/// EE/Emily mention activity over time -- how many, which days, which hours,
/// EE vs Emily -- so you can see the pattern at a glance instead of asking.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  static const _green = AppColors.green;
  int _range = 14;
  Stats? _stats;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Guards against a slower stale request overwriting a newer one if ranges
  // are switched quickly (e.g. tapping 7d then immediately 30d).
  int _requestRange = 0;

  Future<void> _load() async {
    final target = _range;
    _requestRange = target;
    setState(() {
      _loading = true;
      _error = null;   // clear any previous failure so a retry can actually show data
    });
    try {
      final s = await Api.stats(days: target);
      if (!mounted || _requestRange != target) return;   // a newer request has taken over
      setState(() => _stats = s);
    } catch (e) {
      if (!mounted || _requestRange != target) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted && _requestRange == target) setState(() => _loading = false);
    }
  }

  /// "2026-08-25" -> "08-25"; anything shorter is shown as-is (never throws).
  static String _shortDate(String d) => d.length > 5 ? d.substring(5) : d;

  void _setRange(int d) {
    if (d == _range) return;   // already showing this range -- no need to refetch
    setState(() => _range = d);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppColors.card(dark);
    final muted = Theme.of(context).colorScheme.onSurface.withOpacity(0.55);

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _error != null
            ? ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(children: [
                    Text('Could not load stats:\n$_error',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    RetryButton(onPressed: _load),
                  ]),
                ),
              ])
            : ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                children: [
                  _rangeSeg(cardBg, muted),
                  const SizedBox(height: 14),
                  if (_loading && _stats == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_stats != null) ...[
                    _summaryRow(cardBg, muted),
                    const SizedBox(height: 14),
                    _dailyChart(cardBg, muted, dark),
                    const SizedBox(height: 14),
                    _hourChart(cardBg, muted, dark),
                    const SizedBox(height: 14),
                    _termSplit(cardBg, muted),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _rangeSeg(Color cardBg, Color muted) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.18)),
      ),
      child: Row(
        children: [7, 14, 30].map((d) {
          final on = d == _range;
          return Expanded(
            child: GestureDetector(
              onTap: () => _setRange(d),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: on ? _green : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text('${d}d',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: on ? Colors.black : muted)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _card(Color cardBg, {required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.18)),
        ),
        child: child,
      );

  Widget _summaryRow(Color cardBg, Color muted) {
    final s = _stats!;
    Widget stat(String label, String value) => Expanded(
          child: Column(children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: _green)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 12, color: muted),
                textAlign: TextAlign.center),
          ]),
        );
    return _card(cardBg,
        child: Row(children: [
          stat('posts\n(${s.days}d)', '${s.totalPosts}'),
          Container(width: 1, height: 40, color: muted.withOpacity(0.3)),
          stat('mentions\n(${s.days}d)', '${s.totalMentions}'),
        ]));
  }

  Widget _dailyChart(Color cardBg, Color muted, bool dark) {
    final s = _stats!;
    final maxC = s.perDay.fold(0, (m, d) => d.count > m ? d.count : m).clamp(1, 1 << 30);
    // Only label every Nth day on wider ranges so labels don't collide.
    final labelEvery = s.days <= 7 ? 1 : (s.days <= 14 ? 2 : 5);
    return _card(cardBg,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Mentions per day',
              style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < s.perDay.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(s.perDay[i].count > 0 ? '${s.perDay[i].count}' : '',
                              style: TextStyle(fontSize: 9, color: muted)),
                          const SizedBox(height: 2),
                          Container(
                            height: 68 * (s.perDay[i].count / maxC).clamp(0.02, 1.0),
                            decoration: BoxDecoration(
                              color: _green.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < s.perDay.length; i++)
                Expanded(
                  child: Text(
                    i % labelEvery == 0 ? _shortDate(s.perDay[i].date) : '',
                    style: TextStyle(fontSize: 8.5, color: muted),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ]));
  }

  Widget _hourChart(Color cardBg, Color muted, bool dark) {
    final s = _stats!;
    // A malformed response should never crash the chart, even though our own
    // server always sends exactly 24 entries.
    final hours = List<int>.generate(24, (h) => h < s.perHour.length ? s.perHour[h] : 0);
    final trueMax = hours.fold(0, (m, c) => c > m ? c : m);
    final busiest = trueMax > 0 ? hours.indexOf(trueMax) : -1;
    final denom = trueMax.clamp(1, 1 << 30);   // avoid divide-by-zero for bar heights only
    return _card(cardBg,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              busiest < 0
                  ? 'By hour of day (UTC) · no activity'
                  : 'By hour of day (UTC) · busiest: ${busiest.toString().padLeft(2, '0')}:00',
              style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          SizedBox(
            height: 60,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var h = 0; h < 24; h++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Container(
                        height: 56 * (hours[h] / denom).clamp(0.02, 1.0),
                        decoration: BoxDecoration(
                          color: h == busiest
                              ? _green
                              : _green.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Text('00', style: TextStyle(fontSize: 9, color: muted)),
            const Spacer(),
            Text('12', style: TextStyle(fontSize: 9, color: muted)),
            const Spacer(),
            Text('23', style: TextStyle(fontSize: 9, color: muted)),
          ]),
        ]));
  }

  Widget _termSplit(Color cardBg, Color muted) {
    final s = _stats!;
    final total = s.perTerm.values.fold(0, (a, b) => a + b).clamp(1, 1 << 30);
    return _card(cardBg,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('EE vs Emily',
              style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 16,
              child: Row(children: [
                for (final entry in s.perTerm.entries)
                  Expanded(
                    flex: entry.value,
                    child: Container(
                        color: entry.key == 'EE'
                            ? _green
                            : _green.withOpacity(0.45)),
                  ),
                if (s.perTerm.isEmpty) Expanded(child: Container(color: muted)),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 16, runSpacing: 4, children: [
            for (final entry in s.perTerm.entries)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: entry.key == 'EE' ? _green : _green.withOpacity(0.45),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text('${entry.key}: ${entry.value} '
                    '(${(entry.value / total * 100).round()}%)',
                    style: TextStyle(fontSize: 12.5, color: muted)),
              ]),
          ]),
        ]));
  }
}
