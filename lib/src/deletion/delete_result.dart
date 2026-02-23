import 'delete_action.dart';

/// Result of executing a single [DeleteAction].
class DeleteResult {
  const DeleteResult({
    required this.action,
    required this.success,
    this.error,
  });

  /// The action that was executed.
  final DeleteAction action;

  /// Whether the action succeeded.
  final bool success;

  /// Error message if [success] is false.
  final String? error;
}

/// Summary of all deletion results.
class DeletionSummary {
  const DeletionSummary({required this.results});

  final List<DeleteResult> results;

  int get successCount => results.where((r) => r.success).length;

  int get failureCount => results.length - successCount;

  bool get hasFailures => failureCount > 0;

  int get filesDeleted => results
      .where((r) => r.success && r.action is DeleteFileAction)
      .length;

  int get depsRemoved => results
      .where((r) => r.success && r.action is RemoveDependencyAction)
      .length;

  int get symbolsRemoved => results
      .where((r) => r.success && r.action is RemoveSymbolAction)
      .length;
}
