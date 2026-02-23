/// Actions that can be taken to delete unused code.
sealed class DeleteAction {
  const DeleteAction();

  /// Human-readable description of this action.
  String get description;
}

/// Delete an unused Dart file and its associated part files.
class DeleteFileAction extends DeleteAction {
  const DeleteFileAction({
    required this.filePath,
    this.partFilePaths = const [],
  });

  /// Absolute path to the file to delete.
  final String filePath;

  /// Absolute paths to related part files that should also be deleted.
  final List<String> partFilePaths;

  /// All paths that will be deleted (main file + parts).
  List<String> get allPaths => [filePath, ...partFilePaths];

  @override
  String get description {
    if (partFilePaths.isEmpty) return 'Delete file: $filePath';
    return 'Delete file: $filePath (+ ${partFilePaths.length} part files)';
  }
}

/// Remove an unused dependency from pubspec.yaml.
class RemoveDependencyAction extends DeleteAction {
  const RemoveDependencyAction({
    required this.packageName,
    required this.isDev,
  });

  /// Name of the package to remove.
  final String packageName;

  /// Whether this is a dev dependency.
  final bool isDev;

  @override
  String get description {
    final section = isDev ? 'dev_dependencies' : 'dependencies';
    return 'Remove $packageName from $section';
  }
}

/// Remove unused public symbol declarations from a file.
class RemoveSymbolAction extends DeleteAction {
  const RemoveSymbolAction({
    required this.filePath,
    required this.symbolNames,
  });

  /// Absolute path to the file containing the symbols.
  final String filePath;

  /// Names of the symbols to remove.
  final List<String> symbolNames;

  @override
  String get description =>
      'Remove symbols from $filePath: ${symbolNames.join(', ')}';
}
