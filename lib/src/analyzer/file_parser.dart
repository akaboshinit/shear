import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';

import '../model/file_analysis.dart';
import 'declaration_extractor.dart';
import 'directive_extractor.dart';
import 'identifier_collector.dart';

/// Parses a single Dart file and extracts its directives and declarations.
///
/// Uses syntactic parsing only (Tier 1) for speed.
/// No type resolution is performed.
class FileParser {
  const FileParser();

  /// Parse the file at [absolutePath] and return its analysis.
  FileAnalysis parse(String absolutePath) {
    final result = parseFile(
      path: absolutePath,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );

    final unit = result.unit;

    final directiveExtractor = DirectiveExtractor();
    for (final directive in unit.directives) {
      directive.accept(directiveExtractor);
    }

    final declarationExtractor = DeclarationExtractor(absolutePath);
    for (final declaration in unit.declarations) {
      declaration.accept(declarationExtractor);
    }

    final identifierCollector = IdentifierCollector();
    unit.accept(identifierCollector);

    return FileAnalysis(
      absolutePath: absolutePath,
      imports: directiveExtractor.imports,
      exports: directiveExtractor.exports,
      parts: directiveExtractor.parts,
      partOf: directiveExtractor.partOf,
      publicSymbols: declarationExtractor.symbols,
      libraryName: directiveExtractor.libraryName,
      referencedNames: identifierCollector.referencedNames,
      prefixedReferences: identifierCollector.prefixedReferences,
    );
  }
}
