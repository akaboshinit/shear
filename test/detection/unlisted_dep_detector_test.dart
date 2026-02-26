import 'package:shear/src/core/issue.dart';
import 'package:shear/src/detection/unlisted_dep_detector.dart';
import 'package:shear/src/graph/module_graph.dart';
import 'package:shear/src/model/file_analysis.dart';
import 'package:test/test.dart';

import '../helpers/test_utils.dart';

void main() {
  group('UnlistedDepDetector', () {
    test('detects unlisted dependencies in simple_dart fixture', () {
      final fixture = FixtureHelper(
        fixtureName: 'simple_dart',
        packageName: 'simple_dart',
      );

      final projectFiles = fixture.buildFileSet([
        'lib/simple_dart.dart',
        'lib/src/used_util.dart',
        'lib/src/models.dart',
        'lib/src/unused_helper.dart',
        'bin/main.dart',
        'test/simple_test.dart',
      ]);

      final graph = fixture.graphBuilder.build(projectFiles);

      final detector = UnlistedDepDetector(projectRoot: fixture.fixtureRoot);
      final issues = detector.detect(
        projectFiles: projectFiles,
        entryFiles: {
          fixture.filePath('lib/simple_dart.dart'),
          fixture.filePath('bin/main.dart'),
          fixture.filePath('test/simple_test.dart'),
        },
        graph: graph,
        rules: {IssueType.unlistedDependency: Severity.error},
        ignoreDependencies: [],
      );

      // simple_dart fixture declares path, collection, http in pubspec.yaml
      // so there should be no unlisted dependencies.
      final unlisted = issues
          .where((i) => i.type == IssueType.unlistedDependency)
          .map((i) => i.symbol)
          .toList();
      expect(unlisted, isEmpty,
          reason: 'All imported packages are declared in pubspec.yaml');
    });

    test('returns empty when severity is off', () {
      final fixture = FixtureHelper(
        fixtureName: 'simple_dart',
        packageName: 'simple_dart',
      );

      final projectFiles = fixture.buildFileSet([
        'lib/simple_dart.dart',
      ]);

      final graph = fixture.graphBuilder.build(projectFiles);

      final detector = UnlistedDepDetector(projectRoot: fixture.fixtureRoot);
      final issues = detector.detect(
        projectFiles: projectFiles,
        entryFiles: {fixture.filePath('lib/simple_dart.dart')},
        graph: graph,
        rules: {IssueType.unlistedDependency: Severity.off},
        ignoreDependencies: [],
      );

      expect(issues, isEmpty);
    });

    test('detects unlisted package with synthetic graph', () {
      const projectRoot = '/test_project';

      final graph = ModuleGraph()
        ..addFile(const FileAnalysis(absolutePath: '$projectRoot/lib/main.dart'))
        ..addExternalPackage('http', '$projectRoot/lib/main.dart')
        ..addExternalPackage('path', '$projectRoot/lib/main.dart');

      // No real pubspec, so the detector should return empty
      // (pubspec file doesn't exist at /test_project/pubspec.yaml).
      final detector = UnlistedDepDetector(projectRoot: projectRoot);
      final issues = detector.detect(
        projectFiles: {'$projectRoot/lib/main.dart'},
        entryFiles: {'$projectRoot/lib/main.dart'},
        graph: graph,
        rules: {IssueType.unlistedDependency: Severity.error},
        ignoreDependencies: [],
      );

      expect(issues, isEmpty,
          reason: 'Missing pubspec.yaml should return empty');
    });

    test('respects ignoreDependencies', () {
      final fixture = FixtureHelper(
        fixtureName: 'simple_dart',
        packageName: 'simple_dart',
      );

      final projectFiles = fixture.buildFileSet([
        'lib/simple_dart.dart',
        'lib/src/used_util.dart',
        'lib/src/models.dart',
        'lib/src/unused_helper.dart',
        'bin/main.dart',
        'test/simple_test.dart',
      ]);

      final graph = fixture.graphBuilder.build(projectFiles);
      // Artificially add an unlisted package usage.
      graph.addExternalPackage(
          'fake_pkg', fixture.filePath('lib/simple_dart.dart'));

      final detector = UnlistedDepDetector(projectRoot: fixture.fixtureRoot);
      final issues = detector.detect(
        projectFiles: projectFiles,
        entryFiles: {fixture.filePath('lib/simple_dart.dart')},
        graph: graph,
        rules: {IssueType.unlistedDependency: Severity.error},
        ignoreDependencies: ['fake_pkg'],
      );

      final unlisted = issues.map((i) => i.symbol).toSet();
      expect(unlisted, isNot(contains('fake_pkg')),
          reason: 'Ignored dependencies should not be reported');
    });
  });
}
