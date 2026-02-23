import 'dart:io';

import 'package:shear/src/config/config_loader.dart';
import 'package:shear/src/core/issue.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigLoader', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('config_loader_test_');
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: test_project
version: 0.1.0
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies: {}
dev_dependencies: {}
''');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('returns default config when no config file exists', () async {
      final config = await ConfigLoader.load(tempDir.path);
      expect(config.entry, isNotEmpty);
      expect(config.rules, isNotEmpty);
      expect(config.rules[IssueType.unusedFile], equals(Severity.error));
    });

    test('finds shear.yaml', () async {
      File('${tempDir.path}/shear.yaml').writeAsStringSync('''
entry:
  - "lib/main.dart"
''');

      final config = await ConfigLoader.load(tempDir.path);
      expect(config.entry, contains('lib/main.dart'));
    });

    test('finds shear.yml', () async {
      File('${tempDir.path}/shear.yml').writeAsStringSync('''
entry:
  - "lib/main.dart"
''');

      final config = await ConfigLoader.load(tempDir.path);
      expect(config.entry, contains('lib/main.dart'));
    });

    test('finds .shear.yaml (dotfile)', () async {
      File('${tempDir.path}/.shear.yaml').writeAsStringSync('''
entry:
  - "lib/main.dart"
''');

      final config = await ConfigLoader.load(tempDir.path);
      expect(config.entry, contains('lib/main.dart'));
    });

    test('finds .shear.yml (dotfile)', () async {
      File('${tempDir.path}/.shear.yml').writeAsStringSync('''
entry:
  - "lib/main.dart"
''');

      final config = await ConfigLoader.load(tempDir.path);
      expect(config.entry, contains('lib/main.dart'));
    });

    test('prefers shear.yaml over other config file names', () async {
      File('${tempDir.path}/shear.yaml').writeAsStringSync('''
entry:
  - "lib/primary.dart"
''');
      File('${tempDir.path}/shear.yml').writeAsStringSync('''
entry:
  - "lib/secondary.dart"
''');

      final config = await ConfigLoader.load(tempDir.path);
      expect(config.entry, contains('lib/primary.dart'));
    });

    test('parses ignore patterns', () async {
      File('${tempDir.path}/shear.yaml').writeAsStringSync('''
ignore:
  - "**/*.g.dart"
  - "**/*.freezed.dart"
''');

      final config = await ConfigLoader.load(tempDir.path);
      expect(config.ignore, contains('**/*.g.dart'));
      expect(config.ignore, contains('**/*.freezed.dart'));
    });

    test('parses ignoreDependencies', () async {
      File('${tempDir.path}/shear.yaml').writeAsStringSync('''
ignoreDependencies:
  - flutter
  - build_runner
''');

      final config = await ConfigLoader.load(tempDir.path);
      expect(config.ignoreDependencies, contains('flutter'));
      expect(config.ignoreDependencies, contains('build_runner'));
    });

    test('parses rules with severity levels', () async {
      File('${tempDir.path}/shear.yaml').writeAsStringSync('''
rules:
  unusedFiles: error
  unusedDependencies: warn
  unusedExports: off
''');

      final config = await ConfigLoader.load(tempDir.path);
      expect(config.rules[IssueType.unusedFile], equals(Severity.error));
      expect(config.rules[IssueType.unusedDependency], equals(Severity.warn));
      expect(config.rules[IssueType.unusedExport], equals(Severity.off));
    });

    test('parses plugins', () async {
      File('${tempDir.path}/shear.yaml').writeAsStringSync('''
plugins:
  flutter: true
  build_runner: false
''');

      final config = await ConfigLoader.load(tempDir.path);
      expect(config.plugins['flutter'], isTrue);
      expect(config.plugins['build_runner'], isFalse);
    });

    test('merges user config with defaults', () async {
      File('${tempDir.path}/shear.yaml').writeAsStringSync('''
entry:
  - "lib/custom_entry.dart"
''');

      final config = await ConfigLoader.load(tempDir.path);
      expect(config.entry, contains('lib/custom_entry.dart'));
      expect(config.rules, isNotEmpty);
    });

    test('handles empty YAML file', () async {
      File('${tempDir.path}/shear.yaml').writeAsStringSync('');

      final config = await ConfigLoader.load(tempDir.path);
      expect(config.entry, isNotEmpty);
    });

    test('parses includeEntryExports', () async {
      File('${tempDir.path}/shear.yaml').writeAsStringSync('''
includeEntryExports: true
''');

      final config = await ConfigLoader.load(tempDir.path);
      expect(config.includeEntryExports, isTrue);
    });
  });
}
