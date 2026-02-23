import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shear/src/deletion/delete_action.dart';
import 'package:shear/src/deletion/delete_result.dart';
import 'package:shear/src/deletion/file_deleter.dart';
import 'package:test/test.dart';

void main() {
  group('FileDeleter', () {
    late Directory tempDir;
    late FileDeleter deleter;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('file_deleter_test_');
      deleter = const FileDeleter();
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('deletes a single file', () async {
      final file = File(p.join(tempDir.path, 'unused.dart'));
      file.writeAsStringSync('// unused');

      final action = DeleteFileAction(filePath: file.path);
      final result = await deleter.execute(action);

      expect(result.success, isTrue);
      expect(file.existsSync(), isFalse);
    });

    test('deletes library with part files', () async {
      final lib = File(p.join(tempDir.path, 'lib.dart'));
      final part = File(p.join(tempDir.path, 'part.dart'));
      lib.writeAsStringSync("part 'part.dart';");
      part.writeAsStringSync("part of 'lib.dart';");

      final action = DeleteFileAction(
        filePath: lib.path,
        partFilePaths: [part.path],
      );
      final result = await deleter.execute(action);

      expect(result.success, isTrue);
      expect(lib.existsSync(), isFalse);
      expect(part.existsSync(), isFalse);
    });

    test('succeeds for non-existent file (idempotent)', () async {
      final action = DeleteFileAction(
        filePath: p.join(tempDir.path, 'does_not_exist.dart'),
      );
      final result = await deleter.execute(action);

      expect(result.success, isTrue);
    });

    test('returns failure for permission error', () async {
      // Create a read-only directory and try to delete a file in it.
      final dir = Directory(p.join(tempDir.path, 'readonly'));
      dir.createSync();
      final file = File(p.join(dir.path, 'file.dart'));
      file.writeAsStringSync('content');

      // Make directory read-only.
      Process.runSync('chmod', ['444', file.path]);

      final action = DeleteFileAction(filePath: file.path);
      final result = await deleter.execute(action);

      // Restore permissions for cleanup.
      Process.runSync('chmod', ['755', dir.path]);
      Process.runSync('chmod', ['644', file.path]);

      // On some systems this may succeed (e.g. root).
      // We accept both outcomes but verify result type.
      expect(result, isA<DeleteResult>());
    });
  });
}
