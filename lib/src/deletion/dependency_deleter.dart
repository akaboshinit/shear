import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml_edit/yaml_edit.dart';

import 'delete_action.dart';
import 'delete_result.dart';

/// Removes unused dependencies from pubspec.yaml.
class DependencyDeleter {
  const DependencyDeleter({required this.projectRoot});

  final String projectRoot;

  /// Remove all [actions] from pubspec.yaml in a single read-write cycle.
  Future<List<DeleteResult>> executeBatch(
    List<RemoveDependencyAction> actions,
  ) async {
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));

    if (!await pubspecFile.exists()) {
      return [
        for (final action in actions)
          DeleteResult(
            action: action,
            success: false,
            error: 'pubspec.yaml not found at $projectRoot',
          ),
      ];
    }

    final content = await pubspecFile.readAsString();
    final editor = YamlEditor(content);
    final results = <DeleteResult>[];

    for (final action in actions) {
      final section = action.isDev ? 'dev_dependencies' : 'dependencies';
      try {
        editor.remove([section, action.packageName]);
        results.add(DeleteResult(action: action, success: true));
      } catch (e) {
        results.add(
          DeleteResult(
            action: action,
            success: false,
            error: 'Failed to remove ${action.packageName} from $section: $e',
          ),
        );
      }
    }

    await pubspecFile.writeAsString(editor.toString());
    return results;
  }
}
