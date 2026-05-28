import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:contrib_grid/contrib_grid.dart';
import 'package:contrib_grid/src/contrib_grid_data.dart';

void main() {
  group('normalize', () {
    test('strips time and sums duplicates', () {
      final raw = {
        DateTime(2026, 1, 1, 9, 30): 2,
        DateTime(2026, 1, 1, 17, 0): 3,
        DateTime(2026, 1, 2, 0, 0): 5,
      };
      final out = normalize(raw);
      expect(out[DateTime(2026, 1, 1)], 5);
      expect(out[DateTime(2026, 1, 2)], 5);
      expect(out.length, 2);
    });
  });

  group('resolveRange', () {
    test('defaults to 52 weeks ending today, snapped to whole weeks', () {
      final range = resolveRange(firstDayOfWeek: DateTime.sunday);
      expect(range.dayCount % 7, 0);
      expect(range.start.weekday, DateTime.sunday);
    });

    test('snaps to monday when firstDayOfWeek is monday', () {
      final range = resolveRange(
        start: DateTime(2026, 1, 7), // Wed
        end: DateTime(2026, 1, 14), // Wed
        firstDayOfWeek: DateTime.monday,
      );
      expect(range.start.weekday, DateTime.monday);
      // end snaps forward to sunday
      expect(range.end.weekday, DateTime.sunday);
      expect(range.dayCount % 7, 0);
    });
  });

  group('computeQuantileThresholds', () {
    test('produces monotonic non-decreasing breakpoints', () {
      final thresholds = computeQuantileThresholds([1, 2, 3, 4, 5, 6, 7, 8], 4);
      expect(thresholds.length, 4);
      for (var i = 1; i < thresholds.length; i++) {
        expect(thresholds[i] >= thresholds[i - 1], isTrue);
      }
    });

    test('handles all-equal values', () {
      final thresholds = computeQuantileThresholds([5, 5, 5], 4);
      expect(thresholds.length, 4);
      expect(bucketFor(5, thresholds), 1);
    });

    test('handles empty input', () {
      final thresholds = computeQuantileThresholds(<int>[], 4);
      expect(thresholds.length, 4);
      expect(bucketFor(100, thresholds), 0);
    });
  });

  group('bucketFor', () {
    test('returns 0 for non-positive values', () {
      expect(bucketFor(0, [1, 2, 3, 4]), 0);
      expect(bucketFor(-5, [1, 2, 3, 4]), 0);
    });

    test('returns correct bucket index for positive values', () {
      final thresholds = [1, 3, 6, 10];
      expect(bucketFor(1, thresholds), 1);
      expect(bucketFor(2, thresholds), 1);
      expect(bucketFor(3, thresholds), 2);
      expect(bucketFor(6, thresholds), 3);
      expect(bucketFor(15, thresholds), 4);
    });
  });

  group('ContribGrid widget', () {
    testWidgets('builds with empty values', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ContribGrid(values: const {}),
        ),
      ));
      expect(find.byType(ContribGrid), findsOneWidget);
    });

    testWidgets('renders 53 week columns for default 52-week window',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ContribGrid(
            values: const {},
            endDate: DateTime(2026, 5, 28),
            firstDayOfWeek: DateTime.sunday,
          ),
        ),
      ));
      // Default range is 52*7 = 364 days back, snapped to whole weeks ->
      // 53 columns (52 full weeks + the partial week containing end).
      // We verify by counting Tooltip widgets (one per in-range cell).
      // For a 53-week window, in-range days = 364..371 (>= 364).
      final tooltipFinder = find.byType(Tooltip);
      expect(tester.widgetList(tooltipFinder).length, greaterThanOrEqualTo(364));
    });

    testWidgets('invokes onCellTap with date and value', (tester) async {
      DateTime? tappedDate;
      int? tappedValue;
      final target = DateTime(2026, 5, 20);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ContribGrid(
            values: {target: 7},
            startDate: DateTime(2026, 5, 17), // Sun
            endDate: DateTime(2026, 5, 23), // Sat
            firstDayOfWeek: DateTime.sunday,
            onCellTap: (d, v) {
              tappedDate = d;
              tappedValue = v;
            },
          ),
        ),
      ));

      // Find the cell by its tooltip text.
      final cellFinder = find.byTooltip('2026-05-20: 7');
      expect(cellFinder, findsOneWidget);
      await tester.tap(cellFinder, warnIfMissed: false);
      await tester.pump();

      expect(tappedDate, target);
      expect(tappedValue, 7);
    });

    testWidgets(
        'year selector: cells outside the selected year render as blank placeholders',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ContribGrid(
            values: const {},
            endDate: DateTime(2026, 5, 28),
            firstDayOfWeek: DateTime.sunday,
            showYearSelector: true,
          ),
        ),
      ));
      // Jan 1, 2026 is a Thursday — should have a tooltip.
      expect(find.byTooltip('2026-01-01: 0'), findsOneWidget);
      // Days from late Dec 2025 must NOT appear as cells.
      expect(find.byTooltip('2025-12-28: 0'), findsNothing);
      expect(find.byTooltip('2025-12-29: 0'), findsNothing);
      expect(find.byTooltip('2025-12-30: 0'), findsNothing);
      expect(find.byTooltip('2025-12-31: 0'), findsNothing);
    });

    testWidgets('hides month/weekday labels when flags are false',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ContribGrid(
            values: const {},
            startDate: DateTime(2026, 5, 17),
            endDate: DateTime(2026, 5, 23),
            showMonthLabels: false,
            showWeekdayLabels: false,
          ),
        ),
      ));
      // No 'Mon' / 'Wed' / 'Fri' weekday labels and no month label.
      expect(find.text('Mon'), findsNothing);
      expect(find.text('Wed'), findsNothing);
      expect(find.text('Fri'), findsNothing);
      expect(find.text('May'), findsNothing);
    });
  });
}
