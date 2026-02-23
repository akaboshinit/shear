import 'file_analysis.dart';
import 'public_symbol.dart';

/// A library and all its part files form a single logical unit.
///
/// Part files share the same library scope, so their symbols
/// and imports belong to the parent library.
class LibraryUnit {
  const LibraryUnit({
    required this.libraryPath,
    required this.libraryAnalysis,
    this.partPaths = const [],
    this.partAnalyses = const [],
  });

  final String libraryPath;
  final FileAnalysis libraryAnalysis;
  final List<String> partPaths;
  final List<FileAnalysis> partAnalyses;

  /// All public symbols declared across the library and its parts.
  List<PublicSymbol> get allPublicSymbols => [
        ...libraryAnalysis.publicSymbols,
        for (final part in partAnalyses) ...part.publicSymbols,
      ];

  /// All file paths that make up this library unit.
  Set<String> get allFilePaths => {
        libraryPath,
        ...partPaths,
      };
}
