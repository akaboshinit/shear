import 'dart:convert';

import 'package:shear/src/core/issue.dart';
import 'package:shear/src/reporter/json_reporter.dart';
import 'package:test/test.dart';

void main() {
  group('JsonReporter', () {
    late StringBuffer buffer;
    late JsonReporter reporter;

    setUp(() {
      buffer = StringBuffer();
      reporter = JsonReporter(sink: buffer);
    });

    Map<String, dynamic> reportAndParse(AnalysisResult result) {
      reporter.report(result);
      return jsonDecode(buffer.toString().trim()) as Map<String, dynamic>;
    }

    test('outputs valid JSON', () {
      final json = reportAndParse(const AnalysisResult(issues: [
        Issue(
          type: IssueType.unusedFile,
          severity: Severity.error,
          filePath: 'lib/unused.dart',
          message: 'Unused file',
        ),
      ]));

      expect(json, isA<Map<String, dynamic>>());
    });

    test('includes version field', () {
      final json = reportAndParse(const AnalysisResult(issues: []));
      expect(json['version'], equals('0.1.0'));
    });

    test('includes correct issues array structure', () {
      final json = reportAndParse(const AnalysisResult(issues: [
        Issue(
          type: IssueType.unusedFile,
          severity: Severity.error,
          filePath: 'lib/unused.dart',
          message: 'Unused file',
        ),
        Issue(
          type: IssueType.unusedDependency,
          severity: Severity.error,
          filePath: 'pubspec.yaml',
          symbol: 'http',
          message: 'Unused dependency: http',
        ),
      ]));
      final issues = json['issues'] as List;

      expect(issues, hasLength(2));

      final first = issues[0] as Map<String, dynamic>;
      expect(first['type'], equals('unusedFile'));
      expect(first['severity'], equals('error'));
      expect(first['filePath'], equals('lib/unused.dart'));
      expect(first['message'], equals('Unused file'));
      expect(first.containsKey('symbol'), isFalse);

      final second = issues[1] as Map<String, dynamic>;
      expect(second['symbol'], equals('http'));
    });

    test('includes summary with byType breakdown', () {
      final json = reportAndParse(const AnalysisResult(issues: [
        Issue(
          type: IssueType.unusedFile,
          severity: Severity.error,
          filePath: 'lib/a.dart',
          message: 'Unused file',
        ),
        Issue(
          type: IssueType.unusedExport,
          severity: Severity.warn,
          filePath: 'lib/b.dart',
          symbol: 'foo',
          message: 'Unused export: foo',
        ),
      ]));
      final summary = json['summary'] as Map<String, dynamic>;

      expect(summary['total'], equals(2));
      expect(summary['errors'], equals(1));
      expect(summary['warnings'], equals(1));

      final byType = summary['byType'] as Map<String, dynamic>;
      expect(byType['unusedFile'], equals(1));
      expect(byType['unusedDependency'], equals(0));
      expect(byType['unusedExport'], equals(1));
    });

    test('outputs empty issues array for no issues', () {
      final json = reportAndParse(const AnalysisResult(issues: []));
      final issues = json['issues'] as List;

      expect(issues, isEmpty);
    });

    test('summary shows zeros for no issues', () {
      final json = reportAndParse(const AnalysisResult(issues: []));
      final summary = json['summary'] as Map<String, dynamic>;

      expect(summary['total'], equals(0));
      expect(summary['errors'], equals(0));
      expect(summary['warnings'], equals(0));
    });
  });
}
