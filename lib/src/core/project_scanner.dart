import 'dart:io';

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;

import '../config/shear_config.dart';

/// Discovers all Dart files within the project scope.
class ProjectScanner {
  const ProjectScanner({
    required this.config,
    required this.projectRoot,
  });

  final ShearConfig config;
  final String projectRoot;

  /// Returns all .dart files matching the project scope patterns,
  /// excluding files matching ignore patterns.
  Future<Set<String>> scanProjectFiles() async {
    final projectFiles = <String>{};

    for (final pattern in config.project) {
      final glob = Glob(pattern);
      await for (final entity in glob.list(root: projectRoot)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final normalized = p.normalize(entity.path);
          if (!_isExcluded(normalized)) {
            projectFiles.add(normalized);
          }
        }
      }
    }

    return projectFiles;
  }

  static const _hardCodedExclusions = ['.dart_tool', 'build', '.git'];

  bool _isExcluded(String filePath) {
    final relativePath = p.relative(filePath, from: projectRoot);

    if (_hardCodedExclusions.any(relativePath.startsWith)) {
      return true;
    }

    return config.ignore.any((pattern) => Glob(pattern).matches(relativePath));
  }
}
