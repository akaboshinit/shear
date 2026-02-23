import '../graph/module_graph.dart';

/// Issue types that shear can detect.
enum IssueType {
  unusedFile('Unused files'),
  unusedDependency('Unused dependencies'),
  unusedExport('Unused exports');

  const IssueType(this.label);

  final String label;
}

/// Severity levels for issues.
enum Severity {
  error,
  warn,
  off;

  static Severity fromString(String value) {
    return switch (value) {
      'error' => Severity.error,
      'warn' => Severity.warn,
      'off' => Severity.off,
      _ => throw ArgumentError('Unknown severity: $value'),
    };
  }
}

/// A single issue detected by shear.
class Issue {
  const Issue({
    required this.type,
    required this.severity,
    required this.filePath,
    required this.message,
    this.symbol,
  });

  final IssueType type;
  final Severity severity;
  final String filePath;
  final String message;
  final String? symbol;

  @override
  String toString() => '[$type] $message ($filePath)';
}

/// Result of a full shear analysis run.
class AnalysisResult {
  const AnalysisResult({required this.issues, this.graph});

  final List<Issue> issues;

  /// The module graph used during analysis, if available.
  final ModuleGraph? graph;

  int get totalCount => issues.length;

  bool get hasErrors => issues.any((i) => i.severity == Severity.error);

  bool get hasWarnings => issues.any((i) => i.severity == Severity.warn);

  int get errorCount =>
      issues.where((i) => i.severity == Severity.error).length;

  int get warningCount =>
      issues.where((i) => i.severity == Severity.warn).length;

  Map<IssueType, List<Issue>> get groupedByType {
    final grouped = <IssueType, List<Issue>>{};
    for (final issue in issues) {
      grouped.putIfAbsent(issue.type, () => []).add(issue);
    }
    return grouped;
  }
}
