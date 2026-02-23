import 'dart:collection';

import '../model/file_analysis.dart';

/// Dependency graph of all Dart files in a project.
class ModuleGraph {
  /// All analyzed files: absolute path -> FileAnalysis.
  final Map<String, FileAnalysis> files = {};

  /// Forward edges: source file -> set of target files it imports/exports/parts.
  final Map<String, Set<String>> edges = {};

  /// Reverse edges: target file -> set of source files that reference it.
  final Map<String, Set<String>> reverseEdges = {};

  /// Part-of relationships: part file path -> parent library path.
  final Map<String, String> partToLibrary = {};

  /// Library to its parts: library path -> set of part file paths.
  final Map<String, Set<String>> libraryToParts = {};

  /// External package usage: package name -> set of files that import it.
  final Map<String, Set<String>> externalPackageUsage = {};

  /// Add a file analysis result.
  void addFile(FileAnalysis analysis) {
    files[analysis.absolutePath] = analysis;
  }

  /// Add an edge from [source] to [target] (internal file reference).
  void addEdge(String source, String target) {
    edges.putIfAbsent(source, () => {}).add(target);
    reverseEdges.putIfAbsent(target, () => {}).add(source);
  }

  /// Record that [packageName] is imported from [fromFile].
  void addExternalPackage(String packageName, String fromFile) {
    externalPackageUsage.putIfAbsent(packageName, () => {}).add(fromFile);
  }

  /// Record a part relationship.
  void addPartRelation(String libraryPath, String partPath) {
    partToLibrary[partPath] = libraryPath;
    libraryToParts.putIfAbsent(libraryPath, () => {}).add(partPath);
  }

  /// Compute all files reachable from [entryFiles] using BFS.
  Set<String> computeReachable(Set<String> entryFiles) {
    final reachable = <String>{};
    final queue = Queue<String>.from(entryFiles);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (!reachable.add(current)) continue;

      final targets = edges[current];
      if (targets != null) {
        queue.addAll(targets.where((t) => !reachable.contains(t)));
      }

      final parent = partToLibrary[current];
      if (parent != null && !reachable.contains(parent)) {
        queue.add(parent);
      }

      final parts = libraryToParts[current];
      if (parts != null) {
        queue.addAll(parts.where((p) => !reachable.contains(p)));
      }
    }

    return reachable;
  }

  /// Get all external packages used from a subset of files.
  Set<String> externalPackagesFromFiles(Set<String> filePaths) {
    return {
      for (final entry in externalPackageUsage.entries)
        if (entry.value.any(filePaths.contains)) entry.key,
    };
  }
}
