import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shear/src/deletion/delete_action.dart';
import 'package:shear/src/deletion/dependency_deleter.dart';
import 'package:test/test.dart';

void main() {
  group('DependencyDeleter', () {
    late Directory tempDir;
    late String pubspecPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('dep_deleter_test_');
      pubspecPath = p.join(tempDir.path, 'pubspec.yaml');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('removes a regular dependency', () async {
      File(pubspecPath).writeAsStringSync('''
name: test_app
dependencies:
  path: ^1.0.0
  http: ^1.0.0
''');

      final deleter = DependencyDeleter(projectRoot: tempDir.path);
      final actions = [
        const RemoveDependencyAction(packageName: 'http', isDev: false),
      ];
      final results = await deleter.executeBatch(actions);

      expect(results, hasLength(1));
      expect(results.first.success, isTrue);

      final content = File(pubspecPath).readAsStringSync();
      expect(content, isNot(contains('http')));
      expect(content, contains('path'));
    });

    test('removes a dev dependency', () async {
      File(pubspecPath).writeAsStringSync('''
name: test_app
dev_dependencies:
  test: ^1.0.0
  mockito: ^5.0.0
''');

      final deleter = DependencyDeleter(projectRoot: tempDir.path);
      final actions = [
        const RemoveDependencyAction(packageName: 'mockito', isDev: true),
      ];
      final results = await deleter.executeBatch(actions);

      expect(results, hasLength(1));
      expect(results.first.success, isTrue);

      final content = File(pubspecPath).readAsStringSync();
      expect(content, isNot(contains('mockito')));
      expect(content, contains('test'));
    });

    test('preserves comments in pubspec.yaml', () async {
      File(pubspecPath).writeAsStringSync('''
name: test_app
# Important comment
dependencies:
  path: ^1.0.0
  http: ^1.0.0  # remove this
''');

      final deleter = DependencyDeleter(projectRoot: tempDir.path);
      final actions = [
        const RemoveDependencyAction(packageName: 'http', isDev: false),
      ];
      await deleter.executeBatch(actions);

      final content = File(pubspecPath).readAsStringSync();
      expect(content, contains('# Important comment'));
      expect(content, contains('path'));
    });

    test('removes multiple dependencies in a batch', () async {
      File(pubspecPath).writeAsStringSync('''
name: test_app
dependencies:
  path: ^1.0.0
  http: ^1.0.0
  yaml: ^3.0.0
''');

      final deleter = DependencyDeleter(projectRoot: tempDir.path);
      final actions = [
        const RemoveDependencyAction(packageName: 'http', isDev: false),
        const RemoveDependencyAction(packageName: 'yaml', isDev: false),
      ];
      final results = await deleter.executeBatch(actions);

      expect(results, hasLength(2));
      expect(results.every((r) => r.success), isTrue);

      final content = File(pubspecPath).readAsStringSync();
      expect(content, isNot(contains('http')));
      expect(content, isNot(contains('yaml')));
      expect(content, contains('path'));
    });

    test('fails when pubspec.yaml does not exist', () async {
      final deleter = DependencyDeleter(projectRoot: tempDir.path);
      final actions = [
        const RemoveDependencyAction(packageName: 'http', isDev: false),
      ];
      final results = await deleter.executeBatch(actions);

      expect(results, hasLength(1));
      expect(results.first.success, isFalse);
      expect(results.first.error, isNotNull);
    });

    test('reports failure for non-existent package', () async {
      File(pubspecPath).writeAsStringSync('''
name: test_app
dependencies:
  path: ^1.0.0
''');

      final deleter = DependencyDeleter(projectRoot: tempDir.path);
      final actions = [
        const RemoveDependencyAction(
          packageName: 'nonexistent',
          isDev: false,
        ),
      ];
      final results = await deleter.executeBatch(actions);

      expect(results, hasLength(1));
      expect(results.first.success, isFalse);
    });
  });
}
