import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/issue.dart';
import '../core/shear_analyzer.dart';
import '../reporter/console_reporter.dart';
import '../reporter/html_reporter.dart';
import '../reporter/json_reporter.dart';
import '../reporter/reporter.dart';

/// The main 'analyze' command that runs shear analysis.
class AnalyzeCommand extends Command<int> {
  AnalyzeCommand() {
    argParser
      ..addMultiOption(
        'include',
        help: 'Issue types to include.',
        allowed: ['files', 'dependencies', 'exports'],
        defaultsTo: ['files', 'dependencies', 'exports'],
      )
      ..addOption(
        'reporter',
        abbr: 'r',
        help: 'Output format.',
        allowed: ['console', 'json', 'html'],
        defaultsTo: 'console',
      )
      ..addFlag(
        'strict',
        help: 'Treat warnings as errors (non-zero exit code).',
        defaultsTo: false,
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Write report to a file instead of stdout.',
      )
      ..addFlag(
        'verbose',
        help: 'Show detailed analysis information.',
        defaultsTo: false,
      );
  }

  @override
  String get name => 'analyze';

  @override
  String get description => 'Analyze the project for unused code.';

  @override
  Future<int> run() async {
    final projectRoot =
        globalResults?['directory'] as String? ?? Directory.current.path;
    final absolute = p.canonicalize(projectRoot);
    final verbose = argResults!['verbose'] as bool;

    if (verbose) {
      stderr.writeln('Analyzing $absolute...');
    }

    const analyzer = ShearAnalyzer();
    final result = await analyzer.analyze(absolute);

    final included = (argResults!['include'] as List<String>).toSet();
    final filteredIssues = result.issues
        .where((issue) => included.contains(_categoryOf(issue.type)))
        .toList();

    final filteredResult = AnalysisResult(issues: filteredIssues);

    final outputPath = argResults!['output'] as String?;
    IOSink? fileSink;
    if (outputPath != null) {
      fileSink = File(outputPath).openWrite();
    }

    final reporter = _createReporter(
      argResults!['reporter'] as String,
      verbose: verbose,
      sink: fileSink,
    );
    reporter.report(filteredResult);

    if (fileSink != null) {
      await fileSink.flush();
      await fileSink.close();
      if (verbose) {
        stderr.writeln('Report written to $outputPath');
      }
    }

    final strict = argResults!['strict'] as bool;
    if (filteredResult.hasErrors) return 1;
    if (strict && filteredResult.hasWarnings) return 1;
    return 0;
  }

  static String _categoryOf(IssueType type) {
    return switch (type) {
      IssueType.unusedFile => 'files',
      IssueType.unusedDependency => 'dependencies',
      IssueType.unusedExport => 'exports',
    };
  }

  Reporter _createReporter(
    String format, {
    required bool verbose,
    StringSink? sink,
  }) {
    return switch (format) {
      'json' => JsonReporter(sink: sink),
      'html' => HtmlReporter(sink: sink),
      _ => ConsoleReporter(verbose: verbose, sink: sink),
    };
  }
}
