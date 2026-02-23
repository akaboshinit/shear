import 'dart:convert';
import 'dart:io';

import '../core/issue.dart';
import 'reporter.dart';

/// Machine-readable JSON output reporter.
class JsonReporter implements Reporter {
  const JsonReporter({StringSink? sink}) : _sink = sink;

  final StringSink? _sink;

  StringSink get _out => _sink ?? stdout;

  @override
  void report(AnalysisResult result) {
    final output = {
      'version': '0.1.0',
      'issues': result.issues
          .map((i) => {
                'type': i.type.name,
                'severity': i.severity.name,
                'filePath': i.filePath,
                if (i.symbol != null) 'symbol': i.symbol,
                'message': i.message,
              })
          .toList(),
      'summary': {
        'total': result.totalCount,
        'errors': result.errorCount,
        'warnings': result.warningCount,
        'byType': {
          for (final type in IssueType.values)
            type.name: result.groupedByType[type]?.length ?? 0,
        },
      },
    };

    _out.writeln(const JsonEncoder.withIndent('  ').convert(output));
  }
}
