import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shear/src/deletion/delete_action.dart';
import 'package:shear/src/deletion/delete_executor.dart';
import 'package:shear/src/graph/module_graph.dart';
import 'package:test/test.dart';

void main() {
  group('DeleteExecutor', () {
    late Directory tempDir;
    late ModuleGraph graph;
    late DeleteExecutor executor;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('delete_executor_test_');
      graph = ModuleGraph();
      executor = DeleteExecutor(
        projectRoot: tempDir.path,
        graph: graph,
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('returns empty summary for empty actions', () async {
      final summary = await executor.execute([]);

      expect(summary.results, isEmpty);
      expect(summary.successCount, 0);
      expect(summary.failureCount, 0);
      expect(summary.hasFailures, isFalse);
    });

    test('executes mixed actions', () async {
      // Create a file to delete.
      final unusedFile = File(p.join(tempDir.path, 'unused.dart'));
      unusedFile.writeAsStringSync('// unused');

      // Create a file with symbols to remove.
      final modelsFile = File(p.join(tempDir.path, 'models.dart'));
      modelsFile.writeAsStringSync('''
class Foo {}

class Bar {}
''');

      // Create pubspec.yaml.
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: test_app
dependencies:
  path: ^1.0.0
  http: ^1.0.0
''');

      final actions = <DeleteAction>[
        DeleteFileAction(filePath: unusedFile.path),
        RemoveSymbolAction(
          filePath: modelsFile.path,
          symbolNames: ['Foo'],
        ),
        const RemoveDependencyAction(packageName: 'http', isDev: false),
      ];

      final summary = await executor.execute(actions);

      expect(summary.successCount, 3);
      expect(summary.failureCount, 0);
      expect(summary.filesDeleted, 1);
      expect(summary.symbolsRemoved, 1);
      expect(summary.depsRemoved, 1);

      expect(unusedFile.existsSync(), isFalse);

      final modelsContent = modelsFile.readAsStringSync();
      expect(modelsContent, isNot(contains('Foo')));
      expect(modelsContent, contains('Bar'));

      final pubspecContent =
          File(p.join(tempDir.path, 'pubspec.yaml')).readAsStringSync();
      expect(pubspecContent, isNot(contains('http')));
    });

    test('continues execution on partial failure', () async {
      // Create one valid file and one invalid action.
      final validFile = File(p.join(tempDir.path, 'valid.dart'));
      validFile.writeAsStringSync('// valid');

      final actions = <DeleteAction>[
        DeleteFileAction(filePath: validFile.path),
        RemoveSymbolAction(
          filePath: p.join(tempDir.path, 'nonexistent.dart'),
          symbolNames: ['Missing'],
        ),
      ];

      final summary = await executor.execute(actions);

      expect(summary.successCount, 1);
      expect(summary.failureCount, 1);
      expect(summary.hasFailures, isTrue);
    });
  });
}
