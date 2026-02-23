import 'import_info.dart';
import 'public_symbol.dart';

/// Result of analyzing a single Dart file.
class FileAnalysis {
  const FileAnalysis({
    required this.absolutePath,
    this.imports = const [],
    this.exports = const [],
    this.parts = const [],
    this.partOf,
    this.publicSymbols = const [],
    this.libraryName,
    this.referencedNames = const {},
    this.prefixedReferences = const {},
  });

  factory FileAnalysis.empty(String absolutePath) =>
      FileAnalysis(absolutePath: absolutePath);

  final String absolutePath;
  final List<ImportInfo> imports;
  final List<ExportInfo> exports;
  final List<PartInfo> parts;
  final PartOfInfo? partOf;
  final List<PublicSymbol> publicSymbols;

  /// The library name from a `library` directive, if present.
  final String? libraryName;

  /// Non-prefixed identifiers referenced in the file body.
  ///
  /// Populated by [IdentifierCollector] during parsing.
  /// Used by [UnusedExportDetector] to determine actual symbol usage
  /// in bare imports (without `show`/`hide`).
  final Set<String> referencedNames;

  /// Prefixed identifier references grouped by prefix name.
  ///
  /// For `import 'x.dart' as p; p.Foo();` this contains `{'p': {'Foo'}}`.
  final Map<String, Set<String>> prefixedReferences;

  /// Whether this file is a part file (has part of directive).
  bool get isPartFile => partOf != null;

  /// All external package names imported by this file.
  Set<String> get importedPackages => imports
      .where((i) => i.uriKind == UriKind.package)
      .map((i) => i.packageName!)
      .toSet();

  /// All external package names exported by this file.
  Set<String> get exportedPackages => exports
      .where((e) => e.uriKind == UriKind.package)
      .map((e) => e.packageName!)
      .toSet();
}
