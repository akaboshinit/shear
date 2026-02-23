import '../graph/module_graph.dart';
import 'delete_action.dart';
import 'delete_result.dart';
import 'dependency_deleter.dart';
import 'export_deleter.dart';
import 'file_deleter.dart';

/// Orchestrates execution of [DeleteAction]s in the correct order.
class DeleteExecutor {
  DeleteExecutor({
    required String projectRoot,
    required ModuleGraph graph,
    FileDeleter? fileDeleter,
    DependencyDeleter? dependencyDeleter,
    ExportDeleter? exportDeleter,
  })  : _fileDeleter = fileDeleter ?? const FileDeleter(),
        _dependencyDeleter =
            dependencyDeleter ?? DependencyDeleter(projectRoot: projectRoot),
        _exportDeleter = exportDeleter ?? ExportDeleter(graph: graph);

  final FileDeleter _fileDeleter;
  final DependencyDeleter _dependencyDeleter;
  final ExportDeleter _exportDeleter;

  /// Execute all [actions] and return a summary.
  ///
  /// Execution order: files -> symbols -> dependencies.
  Future<DeletionSummary> execute(List<DeleteAction> actions) async {
    final fileActions = <DeleteFileAction>[];
    final depActions = <RemoveDependencyAction>[];
    final symbolActions = <RemoveSymbolAction>[];

    for (final action in actions) {
      switch (action) {
        case final DeleteFileAction a:
          fileActions.add(a);
        case final RemoveDependencyAction a:
          depActions.add(a);
        case final RemoveSymbolAction a:
          symbolActions.add(a);
      }
    }

    final results = <DeleteResult>[];

    // 1. Delete files first.
    for (final action in fileActions) {
      results.add(await _fileDeleter.execute(action));
    }

    // 2. Remove symbols from remaining files.
    for (final action in symbolActions) {
      results.add(await _exportDeleter.execute(action));
    }

    // 3. Remove dependencies from pubspec.yaml.
    if (depActions.isNotEmpty) {
      results.addAll(await _dependencyDeleter.executeBatch(depActions));
    }

    return DeletionSummary(results: results);
  }
}
