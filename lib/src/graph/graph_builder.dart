import '../analyzer/file_parser.dart';
import '../analyzer/uri_resolver.dart';
import 'module_graph.dart';

/// Builds a [ModuleGraph] by parsing all project files and resolving URIs.
class GraphBuilder {
  const GraphBuilder({
    required this.fileParser,
    required this.uriResolver,
  });

  final FileParser fileParser;
  final UriResolver uriResolver;

  /// Build the module graph from a set of project files.
  ModuleGraph build(Set<String> projectFiles) {
    final graph = ModuleGraph();

    for (final filePath in projectFiles) {
      final analysis = fileParser.parse(filePath);
      graph.addFile(analysis);
    }

    for (final entry in graph.files.entries) {
      final filePath = entry.key;
      final analysis = entry.value;

      for (final import in analysis.imports) {
        _processUri(graph, filePath, import.uri);
        for (final config in import.configurations) {
          _processUri(graph, filePath, config.uri);
        }
      }

      for (final export in analysis.exports) {
        _processUri(graph, filePath, export.uri);
        for (final config in export.configurations) {
          _processUri(graph, filePath, config.uri);
        }
      }

      for (final part in analysis.parts) {
        final resolved = uriResolver.resolve(part.uri, filePath);
        if (resolved is InternalUri) {
          graph.addEdge(filePath, resolved.filePath);
          graph.addPartRelation(filePath, resolved.filePath);
        }
      }

      if (analysis.partOf != null) {
        final partOf = analysis.partOf!;
        if (partOf.uri != null) {
          final resolved = uriResolver.resolve(partOf.uri!, filePath);
          if (resolved is InternalUri) {
            graph.addPartRelation(resolved.filePath, filePath);
          }
        }
      }
    }

    _resolveLegacyPartOf(graph);

    return graph;
  }

  void _processUri(ModuleGraph graph, String fromFile, String uri) {
    final resolved = uriResolver.resolve(uri, fromFile);
    if (resolved == null) return; // dart: import

    switch (resolved) {
      case InternalUri():
        graph.addEdge(fromFile, resolved.filePath);
      case ExternalUri():
        graph.addExternalPackage(resolved.packageName, fromFile);
    }
  }

  void _resolveLegacyPartOf(ModuleGraph graph) {
    for (final entry in graph.files.entries) {
      final partOf = entry.value.partOf;
      if (partOf == null || partOf.uri != null || partOf.libraryName == null) {
        continue;
      }

      final targetLibraryName = partOf.libraryName!;
      for (final libEntry in graph.files.entries) {
        if (libEntry.value.libraryName == targetLibraryName) {
          graph.addPartRelation(libEntry.key, entry.key);
          break;
        }
      }
    }
  }
}
