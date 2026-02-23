import 'package:path/path.dart' as p;

import '../core/issue.dart';
import '../graph/module_graph.dart';
import 'detector.dart';

/// Detects files within the project scope that are never reached
/// from any entry point via import/export/part chains.
class UnusedFileDetector implements Detector {
  @override
  List<Issue> detect({
    required Set<String> projectFiles,
    required Set<String> entryFiles,
    required ModuleGraph graph,
    required Map<IssueType, Severity> rules,
    required List<String> ignoreDependencies,
  }) {
    final severity = rules[IssueType.unusedFile];
    if (severity == null || severity == Severity.off) return const [];

    final reachable = graph.computeReachable(entryFiles);
    final issues = <Issue>[];

    for (final file in projectFiles) {
      if (entryFiles.contains(file)) continue;
      if (reachable.contains(file)) continue;

      final parent = graph.partToLibrary[file];
      if (parent != null && !reachable.contains(parent)) continue;

      final relativePath = p.relative(file, from: p.current);
      issues.add(Issue(
        type: IssueType.unusedFile,
        severity: severity,
        filePath: relativePath,
        message: 'Unused file: not imported from any entry point',
      ));
    }

    return issues;
  }
}
