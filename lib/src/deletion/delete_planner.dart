import 'package:path/path.dart' as p;

import '../core/issue.dart';
import '../graph/module_graph.dart';
import 'delete_action.dart';

/// Converts analysis [Issue]s into executable [DeleteAction]s.
class DeletePlanner {
  const DeletePlanner({
    required this.projectRoot,
    required this.graph,
  });

  final String projectRoot;
  final ModuleGraph graph;

  /// Plan delete actions from the given [issues].
  ///
  /// If [include] is non-null, only issue categories in the set are processed.
  /// Valid values: 'files', 'dependencies', 'exports'.
  List<DeleteAction> plan(
    List<Issue> issues, {
    Set<String>? include,
  }) {
    final filtered = include == null
        ? issues
        : issues.where((i) => include.contains(_categoryOf(i.type))).toList();

    final fileActions = _planFileActions(
      filtered.where((i) => i.type == IssueType.unusedFile),
    );

    final deletedFilePaths =
        fileActions.expand((a) => a.allPaths).toSet();

    final depActions = _planDependencyActions(
      filtered.where((i) => i.type == IssueType.unusedDependency),
    );

    final exportActions = _planExportActions(
      filtered.where((i) => i.type == IssueType.unusedExport),
      deletedFilePaths,
    );

    return [
      ...fileActions,
      ...exportActions,
      ...depActions,
    ];
  }

  String _absolutePath(Issue issue) =>
      p.normalize(p.join(projectRoot, issue.filePath));

  List<DeleteFileAction> _planFileActions(Iterable<Issue> issues) {
    final seen = <String>{};
    final actions = <DeleteFileAction>[];

    for (final issue in issues) {
      final absPath = _absolutePath(issue);

      // Skip part files — they're handled as part of their parent library.
      if (graph.partToLibrary.containsKey(absPath)) continue;

      if (!seen.add(absPath)) continue;

      final parts = graph.libraryToParts[absPath]?.toList() ?? const [];
      actions.add(DeleteFileAction(filePath: absPath, partFilePaths: parts));
    }

    return actions;
  }

  List<RemoveDependencyAction> _planDependencyActions(
    Iterable<Issue> issues,
  ) {
    return [
      for (final issue in issues)
        if (issue.symbol != null)
          RemoveDependencyAction(
            packageName: issue.symbol!,
            isDev: false,
          ),
    ];
  }

  List<RemoveSymbolAction> _planExportActions(
    Iterable<Issue> issues,
    Set<String> deletedFilePaths,
  ) {
    final grouped = <String, List<String>>{};

    for (final issue in issues) {
      if (issue.symbol == null) continue;

      final absPath = _absolutePath(issue);

      // Skip if the file is already being deleted entirely.
      if (deletedFilePaths.contains(absPath)) continue;

      grouped.putIfAbsent(absPath, () => []).add(issue.symbol!);
    }

    return [
      for (final entry in grouped.entries)
        RemoveSymbolAction(filePath: entry.key, symbolNames: entry.value),
    ];
  }

  static String _categoryOf(IssueType type) {
    return switch (type) {
      IssueType.unusedFile => 'files',
      IssueType.unusedDependency => 'dependencies',
      IssueType.unlistedDependency => 'dependencies',
      IssueType.unusedExport => 'exports',
      IssueType.unusedEnumMember => 'enumMembers',
      IssueType.unusedClassMember => 'classMembers',
    };
  }
}
