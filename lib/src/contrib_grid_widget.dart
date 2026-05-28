import 'package:flutter/material.dart';

import 'contrib_color_theme.dart';
import 'contrib_grid_data.dart';

typedef ContribTooltipFormatter = String Function(DateTime date, int value);
typedef ContribCellTapCallback = void Function(DateTime date, int value);

/// A GitHub-style contribution heatmap.
///
/// Pass a `Map<DateTime, int>` of daily values and the widget renders a
/// calendar-aligned grid of colored cells. Days outside the resolved range
/// or with non-positive values use [ContribColorTheme.emptyColor].
class ContribGrid extends StatefulWidget {
  const ContribGrid({
    super.key,
    required this.values,
    this.startDate,
    this.endDate,
    this.firstDayOfWeek = DateTime.sunday,
    this.colorTheme = ContribColorTheme.github,
    this.thresholds,
    this.cellSize = 15.0,
    this.cellSpacing = 3.0,
    this.cellRadius = 2.0,
    this.showMonthLabels = true,
    this.showWeekdayLabels = true,
    this.weekdayLabelStyle,
    this.monthLabelStyle,
    this.tooltipFormatter,
    this.onCellTap,
    this.padding = const EdgeInsets.all(4),
    this.isHalfView = false,
    this.showYearSelector = false,
    this.yearLabelStyle,
  });

  /// Daily values keyed by date. Time components on keys are ignored, and
  /// duplicate dates are summed.
  final Map<DateTime, int> values;

  /// First day shown in the grid (inclusive). Defaults to 52 weeks before
  /// [endDate]. Snapped backward to the configured [firstDayOfWeek].
  final DateTime? startDate;

  /// Last day shown in the grid (inclusive). Defaults to today. Snapped
  /// forward so the visible window spans whole weeks.
  final DateTime? endDate;

  /// Which weekday is rendered as the top row. Use the
  /// `DateTime.monday`..`DateTime.sunday` constants.
  final int firstDayOfWeek;

  /// Color palette for empty + intensity buckets.
  final ContribColorTheme colorTheme;

  /// Bucket lower-bound thresholds. Length must equal `colorTheme.scale.length`.
  /// If null, breakpoints are computed automatically from [values].
  final List<int>? thresholds;

  final double cellSize;
  final double cellSpacing;
  final double cellRadius;

  final bool showMonthLabels;
  final bool showWeekdayLabels;
  final TextStyle? weekdayLabelStyle;
  final TextStyle? monthLabelStyle;

  /// Returns the tooltip text for a cell. Defaults to `yyyy-MM-dd: N`.
  final ContribTooltipFormatter? tooltipFormatter;

  /// Called when a cell is tapped. Receives the date (date-only) and the
  /// resolved value (0 for empty days).
  final ContribCellTapCallback? onCellTap;

  final EdgeInsetsGeometry padding;

  /// When true, the grid is constrained to roughly half its natural width and
  /// becomes horizontally scrollable. Weekday labels (if shown) remain fixed
  /// on the left; month labels and cells scroll together. A scrollbar is
  /// shown along the bottom of the scrollable area.
  final bool isHalfView;

  /// When true, a tappable year header is rendered above the grid. Tapping
  /// the year (or the chevrons beside it) switches the visible window to
  /// another year for which [values] has data. While the selector is active,
  /// [startDate] and [endDate] are ignored — the range becomes
  /// `Jan 1 – Dec 31` of the selected year (clamped to today for the
  /// current year).
  final bool showYearSelector;

  /// Text style for the year header. Defaults to a bold 14pt label.
  final TextStyle? yearLabelStyle;

  @override
  State<ContribGrid> createState() => _ContribGridState();
}

class _ContribGridState extends State<ContribGrid> {
  final ScrollController _scrollController = ScrollController();
  int? _selectedYear;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<int> _computeAvailableYears(Map<DateTime, int> normalized) {
    final years = <int>{};
    for (final d in normalized.keys) {
      years.add(d.year);
    }
    final fallback = (widget.endDate ?? DateTime.now()).year;
    years.add(fallback);
    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  void _cycleYear(List<int> years) {
    if (years.length <= 1) return;
    final current = _selectedYear ?? years.first;
    final idx = years.indexOf(current);
    final next = years[(idx + 1) % years.length];
    setState(() => _selectedYear = next);
  }

  void _stepYear(List<int> years, int delta) {
    if (years.length <= 1) return;
    final current = _selectedYear ?? years.first;
    final idx = years.indexOf(current);
    final nextIdx = idx + delta;
    if (nextIdx < 0 || nextIdx >= years.length) return;
    setState(() => _selectedYear = years[nextIdx]);
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.values;
    final startDate = widget.startDate;
    final endDate = widget.endDate;
    final firstDayOfWeek = widget.firstDayOfWeek;
    final colorTheme = widget.colorTheme;
    final thresholds = widget.thresholds;
    final cellSize = widget.cellSize;
    final cellSpacing = widget.cellSpacing;
    final cellRadius = widget.cellRadius;
    final showMonthLabels = widget.showMonthLabels;
    final showWeekdayLabels = widget.showWeekdayLabels;
    final weekdayLabelStyle = widget.weekdayLabelStyle;
    final monthLabelStyle = widget.monthLabelStyle;
    final tooltipFormatter = widget.tooltipFormatter;
    final onCellTap = widget.onCellTap;
    final padding = widget.padding;
    final isHalfView = widget.isHalfView;
    final showYearSelector = widget.showYearSelector;
    final yearLabelStyleEffective = widget.yearLabelStyle ??
        const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF24292F));

    final normalized = normalize(values);

    final availableYears = _computeAvailableYears(normalized);
    final effectiveYear = showYearSelector
        ? (_selectedYear ?? availableYears.first)
        : null;

    final ResolvedRange range;
    final DateTime dataStart;
    final DateTime dataEnd;
    if (effectiveYear != null) {
      final today = DateTime.now();
      final yearStart = DateTime(effectiveYear, 1, 1);
      final yearEnd = (effectiveYear == today.year)
          ? DateTime(today.year, today.month, today.day)
          : DateTime(effectiveYear, 12, 31);
      range = resolveRange(
        start: yearStart,
        end: yearEnd,
        firstDayOfWeek: firstDayOfWeek,
      );
      dataStart = yearStart;
      dataEnd = yearEnd;
    } else {
      range = resolveRange(
        start: startDate,
        end: endDate,
        firstDayOfWeek: firstDayOfWeek,
      );
      dataStart = range.start;
      dataEnd = range.end;
    }

    final activeThresholds = thresholds ??
        computeQuantileThresholds(normalized.values, colorTheme.scale.length);
    assert(
      activeThresholds.length == colorTheme.scale.length,
      'thresholds length (${activeThresholds.length}) must equal '
      'colorTheme.scale.length (${colorTheme.scale.length})',
    );

    final weeks = _buildWeeks(range);
    final monthLabelStyleEffective = monthLabelStyle ??
        const TextStyle(fontSize: 10, color: Color(0xFF656D76));
    final weekdayLabelStyleEffective = weekdayLabelStyle ??
        const TextStyle(fontSize: 10, color: Color(0xFF656D76));

    // Half-view always reserves space for ~26 weeks (half a year) regardless of
    // how many weeks of data actually exist, so partial-year ranges (e.g. the
    // current year so far) aren't shrunk further.
    const halfViewWeeks = 26;
    final halfViewWidth =
        halfViewWeeks * cellSize + (halfViewWeeks - 1) * cellSpacing;

    final scrollable = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showMonthLabels)
          _MonthLabels(
            weeks: weeks,
            cellSize: cellSize,
            cellSpacing: cellSpacing,
            leftGutter: 0,
            style: monthLabelStyleEffective,
          ),
        _Grid(
          weeks: weeks,
          rangeStart: dataStart,
          rangeEnd: dataEnd,
          values: normalized,
          thresholds: activeThresholds,
          theme: colorTheme,
          cellSize: cellSize,
          cellSpacing: cellSpacing,
          cellRadius: cellRadius,
          tooltipFormatter: tooltipFormatter ?? _defaultTooltipFormatter,
          onCellTap: onCellTap,
        ),
      ],
    );

    Widget buildHalfView(double width) => SizedBox(
          width: width,
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: scrollable,
              ),
            ),
          ),
        );

    final rightSide = isHalfView
        ? LayoutBuilder(
            builder: (context, constraints) {
              // If the parent gives us a finite width, shrink the half-view
              // window to fit (so the widget never overflows and the inner
              // scroll — not an outer one — handles the rest). If the parent
              // is itself a horizontal scroll view (infinite max width), use
              // the nominal half-year width.
              final width = constraints.maxWidth.isFinite
                  ? (constraints.maxWidth < halfViewWidth
                      ? constraints.maxWidth
                      : halfViewWidth)
                  : halfViewWidth;
              return buildHalfView(width);
            },
          )
        : scrollable;

    final gridRow = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showWeekdayLabels)
          Padding(
            padding: EdgeInsets.only(top: showMonthLabels ? 14 : 0),
            child: _WeekdayLabels(
              firstDayOfWeek: firstDayOfWeek,
              cellSize: cellSize,
              cellSpacing: cellSpacing,
              style: weekdayLabelStyleEffective,
              width: _weekdayGutterWidth(),
            ),
          ),
        // Flexible forwards the Row's actual available width (parent width
        // minus the weekday-labels gutter) into the LayoutBuilder inside
        // `rightSide`, so the half-view can clamp to fit. Without this, the
        // Row's mainAxisSize.min passes unbounded constraints to children,
        // and the LayoutBuilder falls back to the full half-year width — the
        // exact case that caused the right-side overflow.
        if (isHalfView) Flexible(child: rightSide) else rightSide,
      ],
    );

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showYearSelector && effectiveYear != null)
            _YearSelector(
              year: effectiveYear,
              canGoPrev: availableYears.indexOf(effectiveYear) <
                  availableYears.length - 1,
              canGoNext: availableYears.indexOf(effectiveYear) > 0,
              style: yearLabelStyleEffective,
              onTapYear: () => _cycleYear(availableYears),
              onPrev: () => _stepYear(availableYears, 1),
              onNext: () => _stepYear(availableYears, -1),
            ),
          gridRow,
        ],
      ),
    );
  }

  double _weekdayGutterWidth() => 28;

  static String _defaultTooltipFormatter(DateTime date, int value) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d: $value';
  }
}

/// One week column: the first day in [days] is the [firstDayOfWeek] day; the
/// list always has 7 entries (some may be outside the resolved range).
class _Week {
  _Week(this.days);
  final List<DateTime> days;
  DateTime get first => days.first;
}

List<_Week> _buildWeeks(ResolvedRange range) {
  final weeks = <_Week>[];
  var cursor = range.start;
  while (!cursor.isAfter(range.end)) {
    final days = List<DateTime>.generate(
      7,
      (i) => cursor.add(Duration(days: i)),
    );
    weeks.add(_Week(days));
    cursor = cursor.add(const Duration(days: 7));
  }
  return weeks;
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.weeks,
    required this.rangeStart,
    required this.rangeEnd,
    required this.values,
    required this.thresholds,
    required this.theme,
    required this.cellSize,
    required this.cellSpacing,
    required this.cellRadius,
    required this.tooltipFormatter,
    required this.onCellTap,
  });

  final List<_Week> weeks;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final Map<DateTime, int> values;
  final List<int> thresholds;
  final ContribColorTheme theme;
  final double cellSize;
  final double cellSpacing;
  final double cellRadius;
  final ContribTooltipFormatter tooltipFormatter;
  final ContribCellTapCallback? onCellTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var w = 0; w < weeks.length; w++) ...[
          if (w > 0) SizedBox(width: cellSpacing),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) SizedBox(height: cellSpacing),
                _buildCell(weeks[w].days[i]),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCell(DateTime day) {
    final inRange = !day.isBefore(rangeStart) && !day.isAfter(rangeEnd);
    if (!inRange) {
      return SizedBox(width: cellSize, height: cellSize);
    }
    final value = values[day] ?? 0;
    final bucket = bucketFor(value, thresholds);
    final color = theme.colorForBucket(bucket);
    final cell = Container(
      width: cellSize,
      height: cellSize,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(cellRadius),
      ),
    );
    final tipped = Tooltip(
      message: tooltipFormatter(day, value),
      waitDuration: const Duration(milliseconds: 300),
      child: cell,
    );
    if (onCellTap == null) return tipped;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onCellTap!(day, value),
      child: tipped,
    );
  }
}

class _WeekdayLabels extends StatelessWidget {
  const _WeekdayLabels({
    required this.firstDayOfWeek,
    required this.cellSize,
    required this.cellSpacing,
    required this.style,
    required this.width,
  });

  final int firstDayOfWeek;
  final double cellSize;
  final double cellSpacing;
  final TextStyle style;
  final double width;

  static const _names = {
    DateTime.monday: 'Mon',
    DateTime.tuesday: 'Tue',
    DateTime.wednesday: 'Wed',
    DateTime.thursday: 'Thu',
    DateTime.friday: 'Fri',
    DateTime.saturday: 'Sat',
    DateTime.sunday: 'Sun',
  };

  @override
  Widget build(BuildContext context) {
    // Label rows 1, 3, 5 (Mon-style: 2nd, 4th, 6th day from top) to mimic GitHub.
    final rows = <Widget>[];
    for (var i = 0; i < 7; i++) {
      final weekday = ((firstDayOfWeek - 1 + i) % 7) + 1;
      final showLabel = i == 1 || i == 3 || i == 5;
      if (i > 0) rows.add(SizedBox(height: cellSpacing));
      rows.add(SizedBox(
        height: cellSize,
        width: width,
        child: showLabel
            ? Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(_names[weekday]!, style: style),
                ),
              )
            : const SizedBox.shrink(),
      ));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class _MonthLabels extends StatelessWidget {
  const _MonthLabels({
    required this.weeks,
    required this.cellSize,
    required this.cellSpacing,
    required this.leftGutter,
    required this.style,
  });

  final List<_Week> weeks;
  final double cellSize;
  final double cellSpacing;
  final double leftGutter;
  final TextStyle style;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final columnWidth = cellSize + cellSpacing; // includes the gap after the cell

    // Identify weeks where a new month begins (first time we see that month).
    final seenMonths = <int>{};
    final labels = <int, String>{}; // week index -> month name

    for (var w = 0; w < weeks.length; w++) {
      // A week "belongs to" a month if any of its days fall in that month
      // AND it's the first week we encounter that month.
      for (final day in weeks[w].days) {
        final key = day.year * 100 + day.month;
        if (!seenMonths.contains(key) && day.day <= 7) {
          seenMonths.add(key);
          labels[w] = _months[day.month - 1];
          break;
        }
      }
    }

    final totalWidth =
        weeks.length * cellSize + (weeks.length - 1) * cellSpacing;

    return SizedBox(
      height: 14,
      child: Padding(
        padding: EdgeInsets.only(left: leftGutter, bottom: 2),
        child: SizedBox(
          width: totalWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final entry in labels.entries)
                Positioned(
                  left: entry.key * columnWidth,
                  top: 0,
                  child: Text(entry.value, style: style),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YearSelector extends StatelessWidget {
  const _YearSelector({
    required this.year,
    required this.canGoPrev,
    required this.canGoNext,
    required this.style,
    required this.onTapYear,
    required this.onPrev,
    required this.onNext,
  });

  final int year;
  final bool canGoPrev;
  final bool canGoNext;
  final TextStyle style;
  final VoidCallback onTapYear;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final disabledColor = (style.color ?? const Color(0xFF24292F)).withValues(alpha: 0.3);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconButton(
            icon: Icons.chevron_left,
            color: canGoPrev ? style.color : disabledColor,
            onTap: canGoPrev ? onPrev : null,
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTapYear,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text('$year', style: style),
            ),
          ),
          _IconButton(
            icon: Icons.chevron_right,
            color: canGoNext ? style.color : disabledColor,
            onTap: canGoNext ? onNext : null,
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
