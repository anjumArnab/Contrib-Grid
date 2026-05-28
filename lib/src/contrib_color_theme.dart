import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Color palette for a [ContribGrid].
///
/// [emptyColor] is used for days with no contributions (value <= 0 or missing).
/// [scale] holds the colors for buckets 1..N ordered from low to high intensity.
/// The length of [scale] defines the number of non-empty buckets.
@immutable
class ContribColorTheme {
  const ContribColorTheme({required this.emptyColor, required this.scale});

  final Color emptyColor;
  final List<Color> scale;

  /// Returns the color for a bucket index in `0..scale.length`.
  /// Bucket 0 means "empty"; buckets 1..N map into [scale].
  Color colorForBucket(int bucket) {
    if (bucket <= 0) return emptyColor;
    final i = bucket - 1;
    if (i >= scale.length) return scale.last;
    return scale[i];
  }

  /// GitHub light-mode green palette (4 intensity steps).
  static const ContribColorTheme github = ContribColorTheme(
    emptyColor: Color(0xFFEBEDF0),
    scale: [
      Color(0xFF9BE9A8),
      Color(0xFF40C463),
      Color(0xFF30A14E),
      Color(0xFF216E39),
    ],
  );

  /// GitHub dark-mode green palette (4 intensity steps).
  static const ContribColorTheme githubDark = ContribColorTheme(
    emptyColor: Color(0xFF161B22),
    scale: [
      Color(0xFF0E4429),
      Color(0xFF006D32),
      Color(0xFF26A641),
      Color(0xFF39D353),
    ],
  );
}
