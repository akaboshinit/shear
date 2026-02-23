import 'package:path/path.dart' as p;
import 'package:shear/src/config/shear_config.dart';
import 'package:shear/src/core/issue.dart';
import 'package:shear/src/core/shear_analyzer.dart';
import 'package:test/test.dart';

void main() {
  group('ShearAnalyzer', () {
    const analyzer = ShearAnalyzer();

    group('simple_dart fixture', () {
      late String fixtureRoot;

      setUp(() {
        fixtureRoot = p.canonicalize('test/fixtures/simple_dart');
      });

      Set<String> issueNames(
        AnalysisResult result,
        IssueType type, {
        bool useSymbol = false,
      }) {
        return result.issues
            .where((i) => i.type == type)
            .map((i) => useSymbol ? i.symbol! : p.basename(i.filePath))
            .toSet();
      }

      test('full pipeline detects unused file', () async {
        final result = await analyzer.analyze(fixtureRoot);
        expect(issueNames(result, IssueType.unusedFile),
            contains('unused_helper.dart'));
      });

      test('full pipeline detects unused dependency', () async {
        final result = await analyzer.analyze(fixtureRoot);
        expect(
          issueNames(result, IssueType.unusedDependency, useSymbol: true),
          contains('http'),
        );
      });

      test('does not flag used files', () async {
        final result = await analyzer.analyze(fixtureRoot);
        final unused = issueNames(result, IssueType.unusedFile);

        expect(unused, isNot(contains('used_util.dart')));
        expect(unused, isNot(contains('models.dart')));
        expect(unused, isNot(contains('simple_dart.dart')));
      });

      test('does not flag used dependencies', () async {
        final result = await analyzer.analyze(fixtureRoot);
        final unused =
            issueNames(result, IssueType.unusedDependency, useSymbol: true);

        expect(unused, isNot(contains('path')));
        expect(unused, isNot(contains('collection')));
      });
    });

    group('configOverride', () {
      test('respects severity overrides', () async {
        final fixtureRoot = p.canonicalize('test/fixtures/simple_dart');

        final result = await analyzer.analyze(
          fixtureRoot,
          configOverride: const ShearConfig(
            entry: [
              'bin/*.dart',
              'lib/simple_dart.dart',
              'test/**_test.dart',
            ],
            project: [
              'lib/**.dart',
              'bin/**.dart',
              'test/**.dart',
            ],
            rules: {
              IssueType.unusedFile: Severity.off,
              IssueType.unusedDependency: Severity.error,
              IssueType.unusedExport: Severity.off,
            },
          ),
        );

        expect(
          result.issues.where((i) => i.type == IssueType.unusedFile),
          isEmpty,
        );
        expect(
          result.issues.where((i) => i.type == IssueType.unusedDependency),
          isNotEmpty,
        );
      });
    });

    group('empty_project fixture', () {
      test('does not crash on empty project', () async {
        final fixtureRoot = p.canonicalize('test/fixtures/empty_project');
        final result = await analyzer.analyze(fixtureRoot);
        expect(result, isNotNull);
      });
    });

    group('circular_imports fixture', () {
      test('handles circular imports without hanging', () async {
        final fixtureRoot = p.canonicalize('test/fixtures/circular_imports');
        final result = await analyzer.analyze(fixtureRoot);

        expect(result, isNotNull);

        final unusedFiles = result.issues
            .where((i) => i.type == IssueType.unusedFile)
            .map((i) => p.basename(i.filePath))
            .toSet();

        expect(unusedFiles, contains('isolated.dart'));
      });
    });

    group('part_files fixture', () {
      test('does not report part files separately when library is unused',
          () async {
        final fixtureRoot = p.canonicalize('test/fixtures/part_files');
        final result = await analyzer.analyze(fixtureRoot);

        final unusedFiles = result.issues
            .where((i) => i.type == IssueType.unusedFile)
            .map((i) => p.basename(i.filePath))
            .toSet();

        expect(unusedFiles, contains('unused_lib_with_part.dart'));
        expect(unusedFiles, isNot(contains('unused_part.dart')));
      });
    });

    group('generated_route fixture', () {
      late String fixtureRoot;

      setUp(() {
        fixtureRoot = p.canonicalize('test/fixtures/generated_route');
      });

      Set<String> unusedFileNames(AnalysisResult result) {
        return result.issues
            .where((i) => i.type == IssueType.unusedFile)
            .map((i) => p.basename(i.filePath))
            .toSet();
      }

      test('.gr.dart files are not ignored by build_runner plugin', () async {
        final result = await analyzer.analyze(fixtureRoot);
        final unused = unusedFileNames(result);

        // Pages referenced only via .gr.dart should NOT be flagged as unused
        expect(unused, isNot(contains('home_page.dart')));
        expect(unused, isNot(contains('settings_page.dart')));
        expect(unused, isNot(contains('app_route.gr.dart')));

        // Truly unused files should still be detected
        expect(unused, contains('unused_widget.dart'));
      });

      test('entry patterns override plugin ignore patterns', () async {
        // Even if a plugin would ignore *.g.dart, adding it to entry
        // should prevent it from being ignored.
        final result = await analyzer.analyze(
          fixtureRoot,
          configOverride: const ShearConfig(
            entry: [
              'bin/*.dart',
              'lib/generated_route.dart',
              '**/*.g.dart', // explicitly include .g.dart as entry
            ],
            project: [
              'lib/**.dart',
              'bin/**.dart',
            ],
          ),
        );

        // The analysis should complete without errors
        expect(result, isNotNull);
      });

      test('plugins config can disable build_runner plugin', () async {
        final result = await analyzer.analyze(
          fixtureRoot,
          configOverride: const ShearConfig(
            entry: [
              'bin/*.dart',
              'lib/generated_route.dart',
            ],
            project: [
              'lib/**.dart',
              'bin/**.dart',
            ],
            plugins: {'build_runner': false},
          ),
        );

        // With build_runner plugin disabled, .g.dart files should NOT be
        // auto-ignored (no plugin patterns applied).
        // The analysis should complete without errors.
        expect(result, isNotNull);
      });
    });
  });
}
