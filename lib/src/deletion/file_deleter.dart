import 'dart:io';

import 'delete_action.dart';
import 'delete_result.dart';

/// Deletes unused files from the filesystem.
class FileDeleter {
  const FileDeleter();

  /// Execute a [DeleteFileAction] by removing all associated files.
  Future<DeleteResult> execute(DeleteFileAction action) async {
    try {
      for (final path in action.allPaths) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
      return DeleteResult(action: action, success: true);
    } on FileSystemException catch (e) {
      return DeleteResult(
        action: action,
        success: false,
        error: e.message,
      );
    }
  }
}
