import 'package:shear/src/core/issue.dart';
import 'package:shear/src/reporter/console_reporter.dart';
import 'package:test/test.dart';

void main() {
  group('ConsoleReporter', () {
    late StringBuffer buffer;
    late ConsoleReporter reporter;

    setUp(() {
      buffer = StringBuffer();
      reporter = ConsoleReporter(sink: buffer);
    });

    String reportAndGet(AnalysisResult result) {
      reporter.report(result);
      return buffer.toString();
    }

    test('prints "No issues found." for empty result', () {
      final output = reportAndGet(const AnalysisResult(issues: []));
      expect(output, contains('No issues found.'));
    });

    test('groups issues by type', () {
      final output = reportAndGet(const AnalysisResult(issues: [
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

      expect(output, contains('Unused files (1)'));
      expect(output, contains('Unused dependencies (1)'));
    });

    test('shows summary with error and warning counts', () {
      final output = reportAndGet(const AnalysisResult(issues: [
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

      expect(output, contains('Summary: 2 issues (1 errors, 1 warnings)'));
    });

    test('shows symbol name when present', () {
      final output = reportAndGet(const AnalysisResult(issues: [
        Issue(
          type: IssueType.unusedExport,
          severity: Severity.warn,
          filePath: 'lib/foo.dart',
          symbol: 'MyClass',
          message: 'Unused export: class "MyClass"',
        ),
      ]));

      expect(output, contains('MyClass  lib/foo.dart'));
    });

    test('shows only file path when symbol is absent', () {
      final output = reportAndGet(const AnalysisResult(issues: [
        Issue(
          type: IssueType.unusedFile,
          severity: Severity.error,
          filePath: 'lib/unused.dart',
          message: 'Unused file',
        ),
      ]));

      expect(output, contains('  lib/unused.dart'));
      expect(output, isNot(contains('  null')));
    });

    test('skips types with no issues', () {
      final output = reportAndGet(const AnalysisResult(issues: [
        Issue(
          type: IssueType.unusedFile,
          severity: Severity.error,
          filePath: 'lib/a.dart',
          message: 'Unused file',
        ),
      ]));

      expect(output, contains('Unused files'));
      expect(output, isNot(contains('Unused dependencies')));
      expect(output, isNot(contains('Unused exports')));
    });

    test('shows summary with only errors when no warnings', () {
      final output = reportAndGet(const AnalysisResult(issues: [
        Issue(
          type: IssueType.unusedFile,
          severity: Severity.error,
          filePath: 'lib/a.dart',
          message: 'Unused file',
        ),
      ]));

      expect(output, contains('Summary: 1 issues (1 errors)'));
      expect(output, isNot(contains('warnings')));
    });
  });
}
