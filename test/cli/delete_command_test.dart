import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('DeleteCommand', () {
    test('--dry-run does not modify files', () async {
      final tempDir = Directory.systemTemp.createTempSync('delete_cmd_test_');
      try {
        // Copy simple_dart fixture.
        _copyFixture('test/fixtures/simple_dart', tempDir.path);

        final result = Process.runSync(
          'dart',
          ['run', 'bin/shear.dart', 'delete', '--dry-run', '-d', tempDir.path],
        );

        expect(result.exitCode, 0);
        expect(
          result.stdout as String,
          contains('dry-run'),
        );

        // File should still exist.
        expect(
          File(p.join(tempDir.path, 'lib', 'src', 'unused_helper.dart'))
              .existsSync(),
          isTrue,
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('--force executes without confirmation', () async {
      final tempDir = Directory.systemTemp.createTempSync('delete_cmd_test_');
      try {
        _copyFixture('test/fixtures/simple_dart', tempDir.path);

        final result = Process.runSync(
          'dart',
          [
            'run',
            'bin/shear.dart',
            'delete',
            '--force',
            '-d',
            tempDir.path,
          ],
        );

        expect(result.exitCode, 0);
        expect(
          result.stdout as String,
          contains('Deletion complete'),
        );

        // Unused file should be deleted.
        expect(
          File(p.join(tempDir.path, 'lib', 'src', 'unused_helper.dart'))
              .existsSync(),
          isFalse,
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('--include files only deletes files', () async {
      final tempDir = Directory.systemTemp.createTempSync('delete_cmd_test_');
      try {
        _copyFixture('test/fixtures/simple_dart', tempDir.path);

        final result = Process.runSync(
          'dart',
          [
            'run',
            'bin/shear.dart',
            'delete',
            '--force',
            '--include',
            'files',
            '-d',
            tempDir.path,
          ],
        );

        expect(result.exitCode, 0);

        // Unused file should be deleted.
        expect(
          File(p.join(tempDir.path, 'lib', 'src', 'unused_helper.dart'))
              .existsSync(),
          isFalse,
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('empty project exits with 0', () async {
      final tempDir = Directory.systemTemp.createTempSync('delete_cmd_test_');
      try {
        _copyFixture('test/fixtures/empty_project', tempDir.path);

        final result = Process.runSync(
          'dart',
          [
            'run',
            'bin/shear.dart',
            'delete',
            '--dry-run',
            '-d',
            tempDir.path,
          ],
        );

        expect(result.exitCode, 0);
        expect(
          result.stdout as String,
          contains('No unused code found'),
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}

/// Copy a fixture directory to a target path.
void _copyFixture(String source, String target) {
  final sourceDir = Directory(source);
  for (final entity in sourceDir.listSync(recursive: true)) {
    final relativePath = p.relative(entity.path, from: sourceDir.path);
    final targetPath = p.join(target, relativePath);

    if (entity is Directory) {
      Directory(targetPath).createSync(recursive: true);
    } else if (entity is File) {
      Directory(p.dirname(targetPath)).createSync(recursive: true);
      entity.copySync(targetPath);
    }
  }
}
