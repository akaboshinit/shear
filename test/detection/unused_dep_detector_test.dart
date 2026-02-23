import 'package:shear/src/core/issue.dart';
import 'package:shear/src/detection/unused_dep_detector.dart';
import 'package:test/test.dart';

import '../helpers/test_utils.dart';

void main() {
  group('UnusedDepDetector', () {
    test('detects unused dependencies in simple_dart fixture', () {
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

      final entryFiles = <String>{
        fixture.filePath('lib/simple_dart.dart'),
        fixture.filePath('bin/main.dart'),
        fixture.filePath('test/simple_test.dart'),
      };

      final detector = UnusedDepDetector(projectRoot: fixture.fixtureRoot);
      final issues = detector.detect(
        projectFiles: projectFiles,
        entryFiles: entryFiles,
        graph: graph,
        rules: {
          IssueType.unusedDependency: Severity.error,
        },
        ignoreDependencies: [],
      );

      final unusedDeps = issues
          .where((i) => i.type == IssueType.unusedDependency)
          .map((i) => i.symbol)
          .toList();
      expect(unusedDeps, contains('http'));
      expect(unusedDeps, isNot(contains('path')));
      expect(unusedDeps, isNot(contains('collection')));

      // dev dependencies should not be checked
      expect(issues.length, equals(unusedDeps.length));
    });

    test(
        'does not report platform endorsement packages when parent is used',
        () {
      final fixture = FixtureHelper(
        fixtureName: 'platform_deps',
        packageName: 'platform_deps',
      );

      final projectFiles = fixture.buildFileSet([
        'lib/platform_deps.dart',
        'lib/src/app.dart',
      ]);

      final graph = fixture.graphBuilder.build(projectFiles);

      final detector = UnusedDepDetector(projectRoot: fixture.fixtureRoot);
      final issues = detector.detect(
        projectFiles: projectFiles,
        entryFiles: {fixture.filePath('lib/platform_deps.dart')},
        graph: graph,
        rules: {IssueType.unusedDependency: Severity.error},
        ignoreDependencies: [],
      );

      final unusedDeps = issues
          .where((i) => i.type == IssueType.unusedDependency)
          .map((i) => i.symbol)
          .toSet();

      // Platform endorsement packages should NOT be reported as unused
      // because their parent packages (google_sign_in, shared_preferences)
      // are used.
      expect(unusedDeps, isNot(contains('google_sign_in_ios')),
          reason:
              'Platform endorsement package should not be unused when parent is used');
      expect(unusedDeps, isNot(contains('shared_preferences_android')),
          reason:
              'Platform endorsement package should not be unused when parent is used');

      // Truly unused package should still be detected
      expect(unusedDeps, contains('unused_package'));

      // Parent packages should not be reported as unused
      expect(unusedDeps, isNot(contains('google_sign_in')));
      expect(unusedDeps, isNot(contains('shared_preferences')));
    });

    test(
        'does not report transitive deps pinned from path dependencies',
        () {
      final fixture = FixtureHelper(
        fixtureName: 'transitive_deps',
        packageName: 'transitive_deps',
      );

      final projectFiles = fixture.buildFileSet([
        'lib/transitive_deps.dart',
      ]);

      final graph = fixture.graphBuilder.build(projectFiles);

      final detector = UnusedDepDetector(projectRoot: fixture.fixtureRoot);
      final issues = detector.detect(
        projectFiles: projectFiles,
        entryFiles: {fixture.filePath('lib/transitive_deps.dart')},
        graph: graph,
        rules: {IssueType.unusedDependency: Severity.error},
        ignoreDependencies: [],
      );

      final unusedDeps = issues
          .where((i) => i.type == IssueType.unusedDependency)
          .map((i) => i.symbol)
          .toSet();

      // Transitive deps from local_pkg should NOT be reported as unused
      expect(unusedDeps, isNot(contains('collection')),
          reason:
              'Transitive dep from path dependency should not be unused');
      expect(unusedDeps, isNot(contains('fixnum')),
          reason:
              'Transitive dep from path dependency should not be unused');

      // Truly unused package should still be detected
      expect(unusedDeps, contains('http'));

      // Directly used packages should not be reported
      expect(unusedDeps, isNot(contains('path')));
      expect(unusedDeps, isNot(contains('local_pkg')));
    });

    test(
        'does not report transitive deps resolved via package_graph.json',
        () {
      final fixture = FixtureHelper(
        fixtureName: 'hosted_transitive_deps',
        packageName: 'hosted_transitive_deps',
      );

      final projectFiles = fixture.buildFileSet([
        'lib/hosted_transitive_deps.dart',
      ]);

      final graph = fixture.graphBuilder.build(projectFiles);

      final detector = UnusedDepDetector(projectRoot: fixture.fixtureRoot);
      final issues = detector.detect(
        projectFiles: projectFiles,
        entryFiles: {fixture.filePath('lib/hosted_transitive_deps.dart')},
        graph: graph,
        rules: {IssueType.unusedDependency: Severity.error},
        ignoreDependencies: [],
      );

      final unusedDeps = issues
          .where((i) => i.type == IssueType.unusedDependency)
          .map((i) => i.symbol)
          .toSet();

      // Transitive deps of dio (helper_pkg, util_pkg) should NOT be unused
      expect(unusedDeps, isNot(contains('helper_pkg')),
          reason:
              'Transitive dep via package_graph.json should not be unused');
      expect(unusedDeps, isNot(contains('util_pkg')),
          reason:
              'Transitive dep via package_graph.json should not be unused');

      // Deep transitive dep (helper_pkg -> deep_dep) should also be safe
      expect(unusedDeps, isNot(contains('deep_dep')),
          reason:
              'Deep transitive dep via package_graph.json should not be unused');

      // Truly unused package should still be detected
      expect(unusedDeps, contains('unused_pkg'));

      // Directly used package should not be reported
      expect(unusedDeps, isNot(contains('dio')));
    });
  });
}
