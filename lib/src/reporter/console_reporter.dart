import 'dart:io';

import '../core/issue.dart';
import 'reporter.dart';

/// Human-readable terminal output reporter.
class ConsoleReporter implements Reporter {
  const ConsoleReporter({this.verbose = false, StringSink? sink})
      : _sink = sink;

  final bool verbose;
  final StringSink? _sink;

  StringSink get _out => _sink ?? stdout;

  @override
  void report(AnalysisResult result) {
    if (result.issues.isEmpty) {
      _out.writeln('No issues found.');
      return;
    }

    final grouped = result.groupedByType;

    for (final type in IssueType.values) {
      final issues = grouped[type];
      if (issues == null || issues.isEmpty) continue;

      _out.writeln('');
      _out.writeln('${type.label} (${issues.length})');

      for (final issue in issues) {
        final symbol = issue.symbol;
        if (symbol != null) {
          _out.writeln('  $symbol  ${issue.filePath}');
        } else {
          _out.writeln('  ${issue.filePath}');
        }
      }
    }

    _out.writeln('');
    _printSummary(result);
  }

  void _printSummary(AnalysisResult result) {
    final parts = <String>[];
    if (result.errorCount > 0) {
      parts.add('${result.errorCount} errors');
    }
    if (result.warningCount > 0) {
      parts.add('${result.warningCount} warnings');
    }
    _out.writeln(
      'Summary: ${result.totalCount} issues (${parts.join(', ')})',
    );
  }
}
