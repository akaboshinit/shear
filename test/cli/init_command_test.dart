import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:shear/src/cli/init_command.dart';
import 'package:shear/src/config/config_loader.dart';
import 'package:shear/src/core/issue.dart';
import 'package:test/test.dart';

void main() {
  group('InitCommand', () {
    late Directory tempDir;
    late CommandRunner<int> runner;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('init_command_test_');
      runner = CommandRunner<int>('shear', 'test runner')
        ..argParser.addOption('directory', abbr: 'd', defaultsTo: '.')
        ..addCommand(InitCommand());
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    void writePubspec(String content) {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync(content);
    }

    void writePureDartPubspec() {
      writePubspec('''
name: test_project
version: 0.1.0
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies: {}
dev_dependencies: {}
''');
    }

    void writeFlutterPubspec() {
      writePubspec('''
name: my_app
version: 0.1.0
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.0
''');
    }

    test('generates shear.yaml in project root', () async {
      writePureDartPubspec();

      final exitCode =
          await runner.run(['-d', tempDir.path, 'init']);

      expect(exitCode, equals(0));

      final configFile = File(p.join(tempDir.path, 'shear.yaml'));
      expect(configFile.existsSync(), isTrue);

      final content = configFile.readAsStringSync();
      expect(content, contains('entry:'));
      expect(content, contains('project:'));
      expect(content, contains('ignore:'));
      expect(content, contains('rules:'));
    });

    test('skips when shear.yaml already exists without --force', () async {
      writePureDartPubspec();
      final existingFile = File(p.join(tempDir.path, 'shear.yaml'));
      existingFile.writeAsStringSync('# existing config\n');

      final exitCode =
          await runner.run(['-d', tempDir.path, 'init']);

      expect(exitCode, equals(0));
      expect(existingFile.readAsStringSync(), equals('# existing config\n'));
    });

    test('overwrites existing file with --force', () async {
      writePureDartPubspec();
      final existingFile = File(p.join(tempDir.path, 'shear.yaml'));
      existingFile.writeAsStringSync('# existing config\n');

      final exitCode =
          await runner.run(['-d', tempDir.path, 'init', '--force']);

      expect(exitCode, equals(0));

      final content = existingFile.readAsStringSync();
      expect(content, isNot(equals('# existing config\n')));
      expect(content, contains('entry:'));
    });

    test('generates correct defaults for pure Dart project', () async {
      writePureDartPubspec();

      await runner.run(['-d', tempDir.path, 'init']);

      final content =
          File(p.join(tempDir.path, 'shear.yaml')).readAsStringSync();

      expect(content, contains('bin/*.dart'));
      expect(content, contains('lib/test_project.dart'));
      expect(content, contains('test/**_test.dart'));
      // Should NOT contain Flutter-specific entries
      expect(content, isNot(contains('integration_test')));
      expect(content, isNot(contains('ignoreDependencies:')));
    });

    test('generates correct defaults for Flutter project', () async {
      writeFlutterPubspec();

      await runner.run(['-d', tempDir.path, 'init']);

      final content =
          File(p.join(tempDir.path, 'shear.yaml')).readAsStringSync();

      // Flutter-specific entries
      expect(content, contains('lib/main.dart'));
      expect(content, contains('integration_test'));
      // Flutter ignoreDependencies
      expect(content, contains('ignoreDependencies:'));
      expect(content, contains('flutter'));
      expect(content, contains('flutter_localizations'));
      expect(content, contains('flutter_test'));
      // Plugin detection
      expect(content, contains('plugins:'));
      expect(content, contains('flutter: true'));
      expect(content, contains('build_runner: true'));
    });

    test('generated YAML round-trips through ConfigLoader', () async {
      writePureDartPubspec();

      await runner.run(['-d', tempDir.path, 'init']);

      final config = await ConfigLoader.load(tempDir.path);

      expect(config.entry, contains('bin/*.dart'));
      expect(config.entry, contains('lib/test_project.dart'));
      expect(config.rules[IssueType.unusedFile], equals(Severity.error));
      expect(
          config.rules[IssueType.unusedExport], equals(Severity.warn));
      expect(config.includeEntryExports, isFalse);
    });

    test('returns error when pubspec.yaml is missing', () async {
      // tempDir has no pubspec.yaml
      final exitCode =
          await runner.run(['-d', tempDir.path, 'init']);

      expect(exitCode, equals(1));

      final configFile = File(p.join(tempDir.path, 'shear.yaml'));
      expect(configFile.existsSync(), isFalse);
    });
  });
}
