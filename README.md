# Contrib Grid

Flutter package that renders a GitHub-style contribution heatmap. Pass a `Map<DateTime, int>` of daily values; the widget produces a calendar-aligned grid of small colored squares, one per day.

![contrib_grid](https://raw.githubusercontent.com/anjumArnab/Contrib-Grid/main/contrib_grid.gif)

## Install

```sh
flutter pub add contrib_grid
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:contrib_grid/contrib_grid.dart';

class HeatmapDemo extends StatelessWidget {
  const HeatmapDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final values = <DateTime, int>{
      DateTime(2026, 5, 20): 3,
      DateTime(2026, 5, 21): 7,
      DateTime(2026, 5, 22): 1,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ContribGrid(
        values: values,
        onCellTap: (date, value) => debugPrint('$date -> $value'),
      ),
    );
  }
}
```

## Parameters

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `values` | `Map<DateTime, int>` | required | Daily values. Time on keys is ignored; duplicate dates are summed. |
| `startDate` | `DateTime?` | 52 weeks before `endDate` | First day shown. Snapped backward to `firstDayOfWeek`. |
| `endDate` | `DateTime?` | today | Last day shown. Snapped forward to end of week. |
| `firstDayOfWeek` | `int` | `DateTime.sunday` | Weekday rendered as the top row (1=Mon..7=Sun). |
| `colorTheme` | `ContribColorTheme` | `ContribColorTheme.github` | Empty color + intensity scale. |
| `thresholds` | `List<int>?` | quantile-derived | Lower bound for each bucket. Length must match `colorTheme.scale.length`. |
| `cellSize` | `double` | `15` | Size of each square in logical pixels. |
| `cellSpacing` | `double` | `3` | Gap between cells. |
| `cellRadius` | `double` | `2` | Corner radius for each cell. |
| `showMonthLabels` | `bool` | `true` | Show month names above the grid. |
| `showWeekdayLabels` | `bool` | `true` | Show Mon/Wed/Fri labels on the left. |
| `weekdayLabelStyle` / `monthLabelStyle` | `TextStyle?` | small grey | Override label typography. |
| `tooltipFormatter` | `String Function(DateTime, int)?` | `yyyy-MM-dd: N` | Tooltip text builder. |
| `onCellTap` | `void Function(DateTime, int)?` | none | Tap callback. |
| `padding` | `EdgeInsetsGeometry` | `EdgeInsets.all(4)` | Outer padding. |

## Theming

```dart
ContribGrid(
  values: values,
  colorTheme: const ContribColorTheme(
    emptyColor: Color(0xFFF0F0F0),
    scale: [
      Color(0xFFFFE5B4),
      Color(0xFFFFB347),
      Color(0xFFFF8C00),
      Color(0xFFD2691E),
    ],
  ),
)
```

`ContribColorTheme.githubDark` is also provided.

## Responsiveness

The widget sizes itself to its content (cells × spacing). For narrow screens, wrap it in a horizontally scrolling parent (`SingleChildScrollView(scrollDirection: Axis.horizontal, child: ...)`). Cells are not auto-scaled to avoid blurry rendering — tune `cellSize` to fit your layout.
