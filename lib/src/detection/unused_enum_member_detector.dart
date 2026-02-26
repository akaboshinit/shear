import 'package:path/path.dart' as p;

import '../analyzer/uri_resolver.dart';
import '../core/issue.dart';
import '../graph/module_graph.dart';
import '../model/file_analysis.dart';
import '../model/public_symbol.dart';
import 'detector.dart';

/// Detects enum members (constants) that are never referenced in the project.
///
/// Uses `prefixedReferences` to track `EnumName.member` usage patterns.
/// If `EnumName.values` is referenced, all members are considered used.
class UnusedEnumMemberDetector implements Detector {
  const UnusedEnumMemberDetector({required this.uriResolver});

  final UriResolver uriResolver;

  @override
  List<Issue> detect({
    required Set<String> projectFiles,
    required Set<String> entryFiles,
    required ModuleGraph graph,
    required Map<IssueType, Severity> rules,
    required List<String> ignoreDependencies,
  }) {
    final severity = rules[IssueType.unusedEnumMember];
    if (severity == null || severity == Severity.off) return const [];

    final issues = <Issue>[];

    for (final entry in graph.files.entries) {
      final definingFile = entry.key;
      final analysis = entry.value;

      if (analysis.isPartFile) continue;
      if (!projectFiles.contains(definingFile)) continue;

      // Collect enums from this file and its parts.
      final enums = <PublicSymbol>[];
      _collectEnums(analysis, enums);
      for (final partPath
          in graph.libraryToParts[definingFile] ?? const <String>{}) {
        final partAnalysis = graph.files[partPath];
        if (partAnalysis != null) {
          _collectEnums(partAnalysis, enums);
        }
      }

      for (final enumSymbol in enums) {
        final enumName = enumSymbol.name;
        if (enumSymbol.memberNames.isEmpty) continue;

        // Collect all prefixed references to this enum across the project.
        final usedMembers = <String>{};

        for (final fileEntry in graph.files.entries) {
          final fileAnalysis = fileEntry.value;
          final refs = fileAnalysis.prefixedReferences[enumName];
          if (refs != null) {
            // If `.values` is referenced, all members are used.
            if (refs.contains('values')) {
              usedMembers.addAll(enumSymbol.memberNames);
              break;
            }
            usedMembers.addAll(refs);
          }
        }

        if (usedMembers.length >= enumSymbol.memberNames.length) continue;

        for (final member in enumSymbol.memberNames) {
          if (usedMembers.contains(member)) continue;

          issues.add(Issue(
            type: IssueType.unusedEnumMember,
            severity: severity,
            filePath: p.relative(definingFile, from: p.current),
            symbol: '$enumName.$member',
            message: 'Unused enum member: "$member" in enum "$enumName"',
          ));
        }
      }
    }

    return issues;
  }

  void _collectEnums(FileAnalysis analysis, List<PublicSymbol> enums) {
    for (final symbol in analysis.publicSymbols) {
      if (symbol.kind == SymbolKind.enumDecl) {
        enums.add(symbol);
      }
    }
  }
}
