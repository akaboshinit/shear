import 'package:path/path.dart' as p;
import 'package:shear/src/core/issue.dart';
import 'package:shear/src/detection/unused_file_detector.dart';
import 'package:test/test.dart';

import '../helpers/test_utils.dart';

void main() {
  group('UnusedFileDetector', () {
    test('detects unused files in simple_dart fixture', () {
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

      final detector = UnusedFileDetector();
      final issues = detector.detect(
        projectFiles: projectFiles,
        entryFiles: entryFiles,
        graph: graph,
        rules: {IssueType.unusedFile: Severity.error},
        ignoreDependencies: [],
      );

      final unusedPaths = issues.map((i) => p.basename(i.filePath)).toList();
      expect(unusedPaths, contains('unused_helper.dart'));
      expect(unusedPaths, isNot(contains('used_util.dart')));
      expect(unusedPaths, isNot(contains('models.dart')));
    });
  });
}
