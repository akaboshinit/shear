import 'package:path/path.dart' as p;

import '../analyzer/uri_resolver.dart';
import '../core/issue.dart';
import '../graph/module_graph.dart';
import '../model/file_analysis.dart';
import '../model/import_info.dart';
import '../model/public_symbol.dart';
import 'detector.dart';

/// Detects exported symbols that are never imported anywhere in the project.
///
/// Uses a syntactic heuristic approach (Tier 1):
/// - `import '...' show Foo` -> only Foo is considered used
/// - `import '...'` (no show/hide) -> all symbols considered used (conservative)
/// - Symbols not imported from anywhere -> unused
class UnusedExportDetector implements Detector {
  const UnusedExportDetector({
    required this.uriResolver,
    required this.includeEntryExports,
  });

  final UriResolver uriResolver;
  final bool includeEntryExports;

  @override
  List<Issue> detect({
    required Set<String> projectFiles,
    required Set<String> entryFiles,
    required ModuleGraph graph,
    required Map<IssueType, Severity> rules,
    required List<String> ignoreDependencies,
  }) {
    final severity = rules[IssueType.unusedExport];
    if (severity == null || severity == Severity.off) return const [];

    final issues = <Issue>[];

    for (final entry in graph.files.entries) {
      final definingFile = entry.key;
      final analysis = entry.value;

      if (analysis.isPartFile) continue;
      if (!includeEntryExports && entryFiles.contains(definingFile)) continue;
      if (!projectFiles.contains(definingFile)) continue;

      final declaredSymbols = analysis.publicSymbols.map((s) => s.name).toSet();
      if (declaredSymbols.isEmpty) continue;

      final parts = graph.libraryToParts[definingFile];
      if (parts != null) {
        for (final partPath in parts) {
          final partAnalysis = graph.files[partPath];
          if (partAnalysis != null) {
            declaredSymbols
                .addAll(partAnalysis.publicSymbols.map((s) => s.name));
          }
        }
      }

      final usedSymbols = _collectUsedSymbols(
        definingFile,
        declaredSymbols,
        graph,
      );

      for (final symbolName in declaredSymbols) {
        if (usedSymbols.contains(symbolName)) continue;
        if (_isTransitivelyExported(definingFile, symbolName, graph)) {
          continue;
        }

        final symbol = analysis.publicSymbols
            .where((s) => s.name == symbolName)
            .firstOrNull;
        final kindLabel = symbol?.kind.label ?? 'symbol';

        issues.add(Issue(
          type: IssueType.unusedExport,
          severity: severity,
          filePath: p.relative(definingFile, from: p.current),
          symbol: symbolName,
          message: 'Unused export: $kindLabel "$symbolName"',
        ));
      }
    }

    return issues;
  }

  /// Collect symbols that are imported from [definingFile] by other files.
  Set<String> _collectUsedSymbols(
    String definingFile,
    Set<String> declaredSymbols,
    ModuleGraph graph,
  ) {
    final usedSymbols = <String>{};

    // Extensions are implicitly activated when a file is imported without
    // show/hide combinators, so their names never appear as identifiers in
    // importer code. Collect them upfront to mark as used on bare imports.
    final extensionNames = _collectExtensionNames(definingFile, graph);

    for (final importerEntry in graph.files.entries) {
      final importerFile = importerEntry.key;
      if (importerFile == definingFile) continue;

      final importerAnalysis = importerEntry.value;

      for (final import in importerAnalysis.imports) {
        if (!_importsFile(import, importerFile, definingFile)) continue;

        if (import.showNames.isNotEmpty) {
          usedSymbols.addAll(import.showNames);
        } else if (import.hideNames.isNotEmpty) {
          usedSymbols
              .addAll(declaredSymbols.difference(import.hideNames.toSet()));
        } else {
          usedSymbols.addAll(_resolveReferencedSymbols(
            import,
            importerAnalysis,
            declaredSymbols,
          ));
          usedSymbols.addAll(extensionNames);
        }
      }
    }

    // Symbols referenced within the defining file itself (or its part files)
    // are internally used and must not be reported as unused exports.
    // Without this check, `shear delete` would remove symbol declarations
    // that are still referenced in the same file, causing compile errors.
    _markInternallyUsedSymbols(definingFile, declaredSymbols, usedSymbols, graph);

    return usedSymbols;
  }

  /// Check if an import directive references [definingFile], either as the
  /// primary URI or through a conditional configuration URI.
  bool _importsFile(
    ImportInfo import,
    String importerFile,
    String definingFile,
  ) {
    final resolved = uriResolver.resolve(import.uri, importerFile);
    if (resolved is InternalUri && resolved.filePath == definingFile) {
      return true;
    }
    for (final config in import.configurations) {
      final configResolved = uriResolver.resolve(config.uri, importerFile);
      if (configResolved is InternalUri &&
          configResolved.filePath == definingFile) {
        return true;
      }
    }
    return false;
  }

  /// Resolve which symbols from [declaredSymbols] are actually referenced
  /// by the importer, based on identifier collection data.
  ///
  /// For prefixed imports (`import 'x.dart' as p`), checks
  /// [FileAnalysis.prefixedReferences] for the prefix.
  /// For non-prefixed bare imports, checks [FileAnalysis.referencedNames].
  ///
  /// Falls back to returning all [declaredSymbols] when no identifier data
  /// is available (backward compatibility).
  Set<String> _resolveReferencedSymbols(
    ImportInfo import,
    FileAnalysis importerAnalysis,
    Set<String> declaredSymbols,
  ) {
    if (importerAnalysis.referencedNames.isEmpty &&
        importerAnalysis.prefixedReferences.isEmpty) {
      return declaredSymbols;
    }

    if (import.prefix != null) {
      final prefixRefs =
          importerAnalysis.prefixedReferences[import.prefix] ?? const {};
      return declaredSymbols.intersection(prefixRefs);
    }

    return declaredSymbols.intersection(importerAnalysis.referencedNames);
  }

  /// Mark symbols that are referenced within [definingFile] or its part files
  /// as used, so they are not falsely reported as unused exports.
  ///
  /// A public symbol may not be imported by any other file but still be
  /// referenced within its own file (e.g. a StateNotifier class used as a
  /// type parameter for its own provider). Deleting such a symbol would
  /// cause a compile error.
  void _markInternallyUsedSymbols(
    String definingFile,
    Set<String> declaredSymbols,
    Set<String> usedSymbols,
    ModuleGraph graph,
  ) {
    void check(FileAnalysis? analysis) {
      if (analysis == null || analysis.referencedNames.isEmpty) return;
      usedSymbols.addAll(declaredSymbols.intersection(analysis.referencedNames));
    }

    check(graph.files[definingFile]);
    for (final partPath
        in graph.libraryToParts[definingFile] ?? const <String>{}) {
      check(graph.files[partPath]);
    }
  }

  /// Collect extension symbol names from [definingFile] and its part files.
  ///
  /// Extensions are implicitly applied when the file is imported, so their
  /// names never appear as identifiers in importer code.
  Set<String> _collectExtensionNames(
    String definingFile,
    ModuleGraph graph,
  ) {
    final names = <String>{};

    void addExtensions(FileAnalysis? analysis) {
      if (analysis == null) return;
      for (final s in analysis.publicSymbols) {
        if (s.kind == SymbolKind.extension) names.add(s.name);
      }
    }

    addExtensions(graph.files[definingFile]);
    for (final partPath in graph.libraryToParts[definingFile] ?? const <String>{}) {
      addExtensions(graph.files[partPath]);
    }

    return names;
  }

  /// Check if a symbol is re-exported via export directives.
  bool _isTransitivelyExported(
    String definingFile,
    String symbolName,
    ModuleGraph graph,
  ) {
    for (final exporterEntry in graph.files.entries) {
      final exporterAnalysis = exporterEntry.value;

      for (final export in exporterAnalysis.exports) {
        final resolved = uriResolver.resolve(export.uri, exporterEntry.key);
        if (resolved is! InternalUri) continue;
        if (resolved.filePath != definingFile) continue;

        if (export.showNames.isNotEmpty) {
          if (export.showNames.contains(symbolName)) return true;
        } else if (export.hideNames.isNotEmpty) {
          if (!export.hideNames.contains(symbolName)) return true;
        } else {
          return true;
        }
      }
    }

    return false;
  }
}
