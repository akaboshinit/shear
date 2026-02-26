import 'package:path/path.dart' as p;

import '../core/issue.dart';
import '../graph/module_graph.dart';
import '../model/file_analysis.dart';
import '../model/public_symbol.dart';
import 'detector.dart';

/// Detects class/mixin members that are never referenced in the project.
///
/// Uses a name-based heuristic (no type resolution):
/// - Static members are tracked via `prefixedReferences[ClassName]`
/// - Instance members are tracked via `referencedNames` across all files
///
/// Default severity is `off` due to potential false positives from
/// name collisions across unrelated types.
class UnusedClassMemberDetector implements Detector {
  const UnusedClassMemberDetector();

  @override
  List<Issue> detect({
    required Set<String> projectFiles,
    required Set<String> entryFiles,
    required ModuleGraph graph,
    required Map<IssueType, Severity> rules,
    required List<String> ignoreDependencies,
  }) {
    final severity = rules[IssueType.unusedClassMember];
    if (severity == null || severity == Severity.off) return const [];

    // Collect all referenced names and prefixed references across the project.
    final allReferencedNames = <String>{};
    final allPrefixedRefs = <String, Set<String>>{};

    for (final analysis in graph.files.values) {
      allReferencedNames.addAll(analysis.referencedNames);
      for (final entry in analysis.prefixedReferences.entries) {
        allPrefixedRefs
            .putIfAbsent(entry.key, () => <String>{})
            .addAll(entry.value);
        // Include property access targets (e.g. instance.property) in
        // referenced names so that instance member usage via dot notation
        // is not missed.
        allReferencedNames.addAll(entry.value);
      }
    }

    final issues = <Issue>[];

    for (final entry in graph.files.entries) {
      final definingFile = entry.key;
      final analysis = entry.value;

      if (analysis.isPartFile) continue;
      if (!projectFiles.contains(definingFile)) continue;

      // Collect classes/mixins from this file and its parts.
      final classLikeSymbols = <PublicSymbol>[];
      _collectClassLike(analysis, classLikeSymbols);
      for (final partPath
          in graph.libraryToParts[definingFile] ?? const <String>{}) {
        final partAnalysis = graph.files[partPath];
        if (partAnalysis != null) {
          _collectClassLike(partAnalysis, classLikeSymbols);
        }
      }

      for (final symbol in classLikeSymbols) {
        final className = symbol.name;
        if (symbol.memberNames.isEmpty) continue;

        final prefixRefs = allPrefixedRefs[className] ?? const <String>{};

        for (final member in symbol.memberNames) {
          // Check prefixed references (e.g. ClassName.staticMethod).
          if (prefixRefs.contains(member)) continue;

          // Check non-prefixed references (name-based, conservative).
          if (allReferencedNames.contains(member)) continue;

          issues.add(Issue(
            type: IssueType.unusedClassMember,
            severity: severity,
            filePath: p.relative(definingFile, from: p.current),
            symbol: '$className.$member',
            message:
                'Unused class member: "$member" in ${symbol.kind.label} "$className"',
          ));
        }
      }
    }

    return issues;
  }

  void _collectClassLike(
    FileAnalysis analysis,
    List<PublicSymbol> symbols,
  ) {
    for (final symbol in analysis.publicSymbols) {
      if (symbol.kind == SymbolKind.classDecl ||
          symbol.kind == SymbolKind.mixin) {
        symbols.add(symbol);
      }
    }
  }
}
