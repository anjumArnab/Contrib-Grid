import 'dart:math';

import 'package:flutter/material.dart';
import 'package:contrib_grid/contrib_grid.dart';

void main() => runApp(const ContribGridApp());

class ContribGridApp extends StatelessWidget {
  const ContribGridApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contrib Grid Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const ContribGridExample(),
    );
  }
}

class ContribGridExample extends StatelessWidget {
  const ContribGridExample({super.key});

  Map<DateTime, int> _sampleData() {
    final rng = Random(170);
    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 365));
    final out = <DateTime, int>{};
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      if (rng.nextDouble() < 0.55) {
        out[DateTime(d.year, d.month, d.day)] = rng.nextInt(12);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final values = _sampleData();
    return Scaffold(
      appBar: AppBar(title: const Text('Contrib Grid Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ContribGrid(
          values: values,
          showYearSelector: true,
          isHalfView: true,
          cellSize: 15,
          onCellTap: (date, value) {
            final y = date.year.toString().padLeft(4, '0');
            final m = date.month.toString().padLeft(2, '0');
            final d = date.day.toString().padLeft(2, '0');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$y-$m-$d: $value contributions'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
      ),
    );
  }
}
