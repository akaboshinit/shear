import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shear/src/config/shear_config.dart';
import 'package:shear/src/core/issue.dart';
import 'package:shear/src/core/shear_analyzer.dart';
import 'package:test/test.dart';

import 'diff_util.dart';

/// Runs a golden test for the given fixture.
///
/// Executes [ShearAnalyzer.analyze] on the fixture project,
/// normalizes the output, and compares it against `expected_output.txt`.
///
/// Set `UPDATE_GOLDENS=true` environment variable to auto-update golden files.
Future<void> runGoldenTest(
  String fixtureName, {
  ShearConfig? configOverride,
}) async {
  final fixtureRoot = p.canonicalize('test/fixtures/$fixtureName');
  final goldenFile = File(p.join(fixtureRoot, 'expected_output.txt'));

  const analyzer = ShearAnalyzer();
  final result = await analyzer.analyze(
    fixtureRoot,
    configOverride: configOverride,
  );
  final actual = _formatResult(result, fixtureRoot);

  final updateGoldens =
      Platform.environment['UPDATE_GOLDENS']?.toLowerCase() == 'true';

  if (updateGoldens) {
    goldenFile.writeAsStringSync(actual);
    // ignore: avoid_print
    print('Updated golden file: ${goldenFile.path}');
    return;
  }

  if (!goldenFile.existsSync()) {
    fail(
      'Golden file not found: ${goldenFile.path}\n'
      'Run with UPDATE_GOLDENS=true to generate it.\n\n'
      'Actual output:\n$actual',
    );
  }

  final expected = goldenFile.readAsStringSync();
  if (expected != actual) {
    final diff = generateDiff(expected, actual);
    fail(
      'Golden test mismatch for fixture "$fixtureName".\n'
      'Run with UPDATE_GOLDENS=true to update.\n\n'
      'Diff:\n$diff',
    );
  }
}

/// Format an [AnalysisResult] into a deterministic string for golden comparison.
String _formatResult(AnalysisResult result, String fixtureRoot) {
  if (result.issues.isEmpty) {
    return 'No issues found.\n';
  }

  final buffer = StringBuffer();
  final grouped = result.groupedByType;

  for (final type in IssueType.values) {
    final issues = grouped[type] ?? const [];
    if (issues.isEmpty) continue;

    buffer.writeln('## ${type.label}');

    // Sort issues for deterministic output
    final sorted = List.of(issues)
      ..sort((a, b) {
        final pathCmp = a.filePath.compareTo(b.filePath);
        if (pathCmp != 0) return pathCmp;
        return (a.symbol ?? '').compareTo(b.symbol ?? '');
      });

    for (final issue in sorted) {
      final normalizedPath = _normalizePath(issue.filePath, fixtureRoot);
      final severity = issue.severity.name;
      final symbolPart = issue.symbol != null
          ? '${issue.symbol} ($normalizedPath)'
          : normalizedPath;
      buffer.writeln('  $severity: $symbolPart');
    }

    buffer.writeln();
  }

  return buffer.toString();
}

/// Normalize a file path to be relative to the fixture root.
String _normalizePath(String filePath, String fixtureRoot) {
  final absolute =
      p.isAbsolute(filePath) ? filePath : p.join(p.current, filePath);

  // Only normalize if the resolved path falls within the fixture root.
  // Paths like "pubspec.yaml" from UnusedDepDetector resolve to the CWD's
  // pubspec, not the fixture's, so we keep them as-is.
  if (p.isWithin(fixtureRoot, absolute)) {
    return p.relative(absolute, from: fixtureRoot).replaceAll(r'\', '/');
  }

  // Use posix separators for cross-platform consistency
  return filePath.replaceAll(r'\', '/');
}
