// Pure-Dart helpers for ContribGrid. No Flutter imports — easy to unit test.

/// Strips the time component, returning a `DateTime(y, m, d)` in local time.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Normalizes a `Map<DateTime, int>` so all keys are date-only and any
/// duplicate dates (different times) are summed into a single entry.
Map<DateTime, int> normalize(Map<DateTime, int> raw) {
  final out = <DateTime, int>{};
  raw.forEach((k, v) {
    final key = dateOnly(k);
    out[key] = (out[key] ?? 0) + v;
  });
  return out;
}

/// Resolved date range used by the grid. `start` is inclusive and snapped to
/// the configured first day of the week; `end` is inclusive and snapped to
/// the end of its week (i.e. one day before the next week's first day).
class ResolvedRange {
  const ResolvedRange(this.start, this.end);
  final DateTime start;
  final DateTime end;

  int get dayCount => end.difference(start).inDays + 1;
  int get weekCount => dayCount ~/ 7;
}

/// Resolves the date range for the grid.
///
/// * If [end] is null, uses today (date-only).
/// * If [start] is null, defaults to 52 weeks before [end].
/// * `start` is rolled back to the previous [firstDayOfWeek] (or kept if it
///   already matches), and `end` is rolled forward so the inclusive window
///   spans a whole number of weeks.
///
/// [firstDayOfWeek] uses the `DateTime.monday`..`DateTime.sunday` constants
/// (1..7).
ResolvedRange resolveRange({
  DateTime? start,
  DateTime? end,
  int firstDayOfWeek = DateTime.sunday,
}) {
  final resolvedEnd = dateOnly(end ?? DateTime.now());
  final resolvedStart = dateOnly(start ?? resolvedEnd.subtract(const Duration(days: 7 * 52)));

  final snappedStart = _snapToWeekStart(resolvedStart, firstDayOfWeek);
  final snappedEnd = _snapToWeekEnd(resolvedEnd, firstDayOfWeek);
  return ResolvedRange(snappedStart, snappedEnd);
}

DateTime _snapToWeekStart(DateTime d, int firstDayOfWeek) {
  // DateTime.weekday: Mon=1..Sun=7. Days to roll back to reach firstDayOfWeek.
  final diff = (d.weekday - firstDayOfWeek + 7) % 7;
  return d.subtract(Duration(days: diff));
}

DateTime _snapToWeekEnd(DateTime d, int firstDayOfWeek) {
  // Last day of the week is the day before firstDayOfWeek.
  final lastDayOfWeek = ((firstDayOfWeek - 1 - 1 + 7) % 7) + 1; // firstDayOfWeek - 1 mod 7
  final diff = (lastDayOfWeek - d.weekday + 7) % 7;
  return d.add(Duration(days: diff));
}

/// Returns quartile-style breakpoints over the positive values in [values].
/// The returned list has length [buckets] and is monotonically non-decreasing.
/// The i-th entry (0-based) is the minimum value to qualify for bucket i+1.
///
/// If [values] contains no positive numbers, returns `[1, 1, 1, 1]`-style
/// thresholds so the highest bucket is unreachable and everything maps to 0.
/// If all positive values are equal, returns thresholds that map every
/// non-zero value to the highest bucket.
List<int> computeQuantileThresholds(Iterable<int> values, int buckets) {
  assert(buckets > 0);
  final positives = values.where((v) => v > 0).toList()..sort();
  if (positives.isEmpty) {
    return List<int>.filled(buckets, 1 << 30); // effectively unreachable
  }
  if (positives.first == positives.last) {
    // All equal: every positive value should land in bucket 1.
    return List<int>.generate(
      buckets,
      (i) => i == 0 ? positives.first : positives.first + 1,
    );
  }
  final result = <int>[];
  for (var i = 0; i < buckets; i++) {
    // Lower bound of bucket i+1, expressed as a quantile of positives.
    final q = i / buckets;
    final idx = (q * (positives.length - 1)).round().clamp(0, positives.length - 1);
    var t = positives[idx];
    if (i == 0 && t < 1) t = 1;
    if (result.isNotEmpty && t < result.last) t = result.last;
    result.add(t);
  }
  return result;
}

/// Returns the bucket index for [value] given monotonically non-decreasing
/// [thresholds]. Bucket 0 means "empty" (value <= 0). Bucket N means
/// "value >= thresholds[N-1]" for the largest such N.
int bucketFor(int value, List<int> thresholds) {
  if (value <= 0) return 0;
  var bucket = 0;
  for (var i = 0; i < thresholds.length; i++) {
    if (value >= thresholds[i]) {
      bucket = i + 1;
    } else {
      break;
    }
  }
  return bucket;
}
