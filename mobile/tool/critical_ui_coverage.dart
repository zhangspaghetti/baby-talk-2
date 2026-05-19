import 'dart:io';

const defaultThresholdPercent = 60.0;

const criticalUiFiles = <String>[
  'lib/features/practice/presentation/screens/practice_session_screen.dart',
  'lib/features/practice/presentation/widgets/activation_frame.dart',
  'lib/app/widgets/app_celebration_overlay.dart',
  'lib/features/shell/presentation/widgets/garden_patch_card.dart',
  'lib/features/practice/presentation/widgets/home_garden_mini_entry.dart',
  'lib/features/practice/presentation/widgets/home_growth_summary_card.dart',
  'lib/features/practice/presentation/widgets/home_recent_result_card.dart',
  'lib/features/share/presentation/widgets/share_callout_card.dart',
];

void main(List<String> args) {
  final lcovPath =
      args.where((arg) => !arg.startsWith('--')).firstOrNull ??
      'coverage/lcov.info';
  final threshold = _readThreshold(args);
  final lcovFile = File(lcovPath);
  if (!lcovFile.existsSync()) {
    stderr.writeln('LCOV file not found: $lcovPath');
    exitCode = 2;
    return;
  }

  final records = _parseLcov(lcovFile.readAsLinesSync());
  final selected = <_CoverageRecord>[];
  final missing = <String>[];
  for (final path in criticalUiFiles) {
    final record = records[path];
    if (record == null) {
      missing.add(path);
    } else {
      selected.add(record);
    }
  }

  final hit = selected.fold<int>(0, (sum, record) => sum + record.hit);
  final found = selected.fold<int>(0, (sum, record) => sum + record.found);
  final percent = found == 0 ? 0.0 : hit * 100 / found;

  stdout.writeln('critical_ui_files=${criticalUiFiles.length}');
  stdout.writeln('critical_ui_present=${selected.length}');
  stdout.writeln('critical_ui_missing=${missing.length}');
  stdout.writeln('critical_ui_hit=$hit');
  stdout.writeln('critical_ui_found=$found');
  stdout.writeln('critical_ui_coverage=${percent.toStringAsFixed(2)}%');
  stdout.writeln('critical_ui_threshold=${threshold.toStringAsFixed(2)}%');

  if (missing.isNotEmpty) {
    stderr.writeln('Missing critical UI LCOV records:');
    for (final path in missing) {
      stderr.writeln('- $path');
    }
    exitCode = 3;
    return;
  }

  stdout.writeln('critical_ui_detail:');
  for (final record in selected) {
    stdout.writeln(
      '- ${record.path} ${record.percent.toStringAsFixed(2)}% '
      '(${record.hit}/${record.found})',
    );
  }

  if (percent < threshold) {
    stderr.writeln(
      'Critical UI coverage ${percent.toStringAsFixed(2)}% is below '
      '${threshold.toStringAsFixed(2)}%.',
    );
    exitCode = 1;
  }
}

double _readThreshold(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--min=')) {
      final parsed = double.tryParse(arg.substring('--min='.length));
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return defaultThresholdPercent;
}

Map<String, _CoverageRecord> _parseLcov(List<String> lines) {
  final records = <String, _CoverageRecord>{};
  String? path;
  var found = 0;
  var hit = 0;

  void closeRecord() {
    final currentPath = path;
    if (currentPath == null) {
      return;
    }
    records[currentPath] = _CoverageRecord(
      path: currentPath,
      hit: hit,
      found: found,
    );
    path = null;
    found = 0;
    hit = 0;
  }

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      closeRecord();
      path = _normalizePath(line.substring(3));
      continue;
    }
    if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length < 2) {
        continue;
      }
      found += 1;
      final count = int.tryParse(parts[1]) ?? 0;
      if (count > 0) {
        hit += 1;
      }
      continue;
    }
    if (line == 'end_of_record') {
      closeRecord();
    }
  }
  closeRecord();
  return records;
}

String _normalizePath(String rawPath) {
  final normalized = rawPath.replaceAll('\\', '/');
  final libIndex = normalized.indexOf('/lib/');
  if (libIndex >= 0) {
    return normalized.substring(libIndex + 1);
  }
  if (normalized.startsWith('lib/')) {
    return normalized;
  }
  return normalized;
}

class _CoverageRecord {
  const _CoverageRecord({
    required this.path,
    required this.hit,
    required this.found,
  });

  final String path;
  final int hit;
  final int found;

  double get percent => found == 0 ? 0.0 : hit * 100 / found;
}
