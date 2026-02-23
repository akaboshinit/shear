import 'dart:convert';

import 'package:shear/src/core/issue.dart';
import 'package:shear/src/reporter/html_reporter.dart';
import 'package:test/test.dart';

void main() {
  group('HtmlReporter', () {
    late StringBuffer buffer;
    late HtmlReporter reporter;

    setUp(() {
      buffer = StringBuffer();
      reporter = HtmlReporter(sink: buffer);
    });

    String reportAndGet(AnalysisResult result) {
      reporter.report(result);
      return buffer.toString();
    }

    test('outputs valid HTML document', () {
      final output = reportAndGet(const AnalysisResult(issues: []));

      expect(output, contains('<!DOCTYPE html>'));
      expect(output, contains('<html'));
      expect(output, contains('</html>'));
    });

    test('shows "No issues found" and score 100 for empty result', () {
      final output = reportAndGet(const AnalysisResult(issues: []));

      expect(output, contains('No issues found'));
      expect(output, contains('100'));
    });

    test('shows correct summary counts', () {
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
        Issue(
          type: IssueType.unusedExport,
          severity: Severity.warn,
          filePath: 'lib/c.dart',
          symbol: 'bar',
          message: 'Unused export: bar',
        ),
      ]));

      // Total count
      expect(output, contains('>3<'));
      // Error count
      expect(output, contains('>1<'));
      // Warning count
      expect(output, contains('>2<'));
    });

    test('computes health score correctly', () {
      // errors=2 * 5 = 10, warnings=3 * 2 = 6 → 100 - 16 = 84
      final output = reportAndGet(const AnalysisResult(issues: [
        Issue(
          type: IssueType.unusedFile,
          severity: Severity.error,
          filePath: 'lib/a.dart',
          message: 'Unused file',
        ),
        Issue(
          type: IssueType.unusedFile,
          severity: Severity.error,
          filePath: 'lib/b.dart',
          message: 'Unused file',
        ),
        Issue(
          type: IssueType.unusedExport,
          severity: Severity.warn,
          filePath: 'lib/c.dart',
          symbol: 'x',
          message: 'Unused export: x',
        ),
        Issue(
          type: IssueType.unusedExport,
          severity: Severity.warn,
          filePath: 'lib/d.dart',
          symbol: 'y',
          message: 'Unused export: y',
        ),
        Issue(
          type: IssueType.unusedExport,
          severity: Severity.warn,
          filePath: 'lib/e.dart',
          symbol: 'z',
          message: 'Unused export: z',
        ),
      ]));

      expect(output, contains('84'));
    });

    test('shows green color for score >= 80', () {
      // 1 warning → score = 100 - 2 = 98 → green
      final output = reportAndGet(const AnalysisResult(issues: [
        Issue(
          type: IssueType.unusedExport,
          severity: Severity.warn,
          filePath: 'lib/a.dart',
          symbol: 'x',
          message: 'Unused export: x',
        ),
      ]));

      expect(output, contains('#10b981'));
    });

    test('shows yellow color for score 50-79', () {
      // 5 errors → score = 100 - 25 = 75 → yellow
      final issues = List.generate(
        5,
        (i) => Issue(
          type: IssueType.unusedFile,
          severity: Severity.error,
          filePath: 'lib/$i.dart',
          message: 'Unused file',
        ),
      );
      final output = reportAndGet(AnalysisResult(issues: issues));

      expect(output, contains('#f59e0b'));
    });

    test('shows red color for score < 50', () {
      // 11 errors → score = 100 - 55 = max(0, 45) → red
      final issues = List.generate(
        11,
        (i) => Issue(
          type: IssueType.unusedFile,
          severity: Severity.error,
          filePath: 'lib/$i.dart',
          message: 'Unused file',
        ),
      );
      final output = reportAndGet(AnalysisResult(issues: issues));

      expect(output, contains('#ef4444'));
    });

    test('generates sections for each issue type', () {
      final output = reportAndGet(const AnalysisResult(issues: [
        Issue(
          type: IssueType.unusedFile,
          severity: Severity.error,
          filePath: 'lib/a.dart',
          message: 'Unused file',
        ),
        Issue(
          type: IssueType.unusedDependency,
          severity: Severity.error,
          filePath: 'pubspec.yaml',
          symbol: 'http',
          message: 'Unused dependency: http',
        ),
        Issue(
          type: IssueType.unusedExport,
          severity: Severity.warn,
          filePath: 'lib/b.dart',
          symbol: 'foo',
          message: 'Unused export: foo',
        ),
      ]));

      expect(output, contains('Unused files'));
      expect(output, contains('Unused dependencies'));
      expect(output, contains('Unused exports'));
    });

    test('skips sections for types with no issues', () {
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
      expect(output, isNot(contains('Unused dev dependencies')));
      expect(output, isNot(contains('Unused exports')));
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

      expect(output, contains('MyClass'));
    });

    test('applies severity CSS class', () {
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

      expect(output, contains('severity-error'));
      expect(output, contains('severity-warn'));
    });

    test('contains SVG elements for charts', () {
      final output = reportAndGet(const AnalysisResult(issues: [
        Issue(
          type: IssueType.unusedFile,
          severity: Severity.error,
          filePath: 'lib/a.dart',
          message: 'Unused file',
        ),
      ]));

      expect(output, contains('<svg'));
      expect(output, contains('<circle'));
    });

    test('escapes HTML special characters', () {
      final output = reportAndGet(const AnalysisResult(issues: [
        Issue(
          type: IssueType.unusedFile,
          severity: Severity.error,
          filePath: 'lib/<script>alert("xss")</script>.dart',
          message: 'Unused file',
        ),
      ]));

      expect(output, isNot(contains('<script>alert')));
      expect(output, contains('&lt;script&gt;'));
    });

    test('embeds valid JSON data for filtering', () {
      final output = reportAndGet(const AnalysisResult(issues: [
        Issue(
          type: IssueType.unusedFile,
          severity: Severity.error,
          filePath: 'lib/a.dart',
          message: 'Unused file',
        ),
      ]));

      // Extract JSON from data-issues attribute or script tag
      final jsonMatch = RegExp(r'var\s+issuesData\s*=\s*(\[.*?\]);',
              dotAll: true)
          .firstMatch(output);
      expect(jsonMatch, isNotNull);

      final jsonStr = jsonMatch!.group(1)!;
      final parsed = jsonDecode(jsonStr) as List;
      expect(parsed, hasLength(1));
      expect((parsed[0] as Map)['filePath'], equals('lib/a.dart'));
    });

    test('contains dark mode CSS variables', () {
      final output = reportAndGet(const AnalysisResult(issues: []));

      expect(output, contains('prefers-color-scheme: dark'));
    });
  });
}
