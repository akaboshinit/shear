import '../core/issue.dart';
import '../graph/module_graph.dart';

/// Interface for issue detectors.
abstract class Detector {
  /// Detect issues and return them.
  List<Issue> detect({
    required Set<String> projectFiles,
    required Set<String> entryFiles,
    required ModuleGraph graph,
    required Map<IssueType, Severity> rules,
    required List<String> ignoreDependencies,
  });
}
