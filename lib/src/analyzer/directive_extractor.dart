import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../model/import_info.dart';

/// Extracts import, export, part, and part-of directives from a
/// CompilationUnit's top-level directives.
class DirectiveExtractor extends SimpleAstVisitor<void> {
  final List<ImportInfo> imports = [];
  final List<ExportInfo> exports = [];
  final List<PartInfo> parts = [];
  PartOfInfo? partOf;
  String? libraryName;

  @override
  void visitImportDirective(ImportDirective node) {
    final uri = node.uri.stringValue;
    if (uri == null) return;

    imports.add(ImportInfo(
      uri: uri,
      prefix: node.prefix?.name,
      isDeferred: node.deferredKeyword != null,
      showNames: _extractShowNames(node.combinators),
      hideNames: _extractHideNames(node.combinators),
      configurations: _extractConfigurations(node.configurations),
    ));
  }

  @override
  void visitExportDirective(ExportDirective node) {
    final uri = node.uri.stringValue;
    if (uri == null) return;

    exports.add(ExportInfo(
      uri: uri,
      showNames: _extractShowNames(node.combinators),
      hideNames: _extractHideNames(node.combinators),
      configurations: _extractConfigurations(node.configurations),
    ));
  }

  @override
  void visitPartDirective(PartDirective node) {
    final uri = node.uri.stringValue;
    if (uri != null) {
      parts.add(PartInfo(uri: uri));
    }
  }

  @override
  void visitPartOfDirective(PartOfDirective node) {
    partOf = PartOfInfo(
      uri: node.uri?.stringValue,
      libraryName: node.libraryName?.toString(),
    );
  }

  @override
  void visitLibraryDirective(LibraryDirective node) {
    libraryName = node.name2?.toString();
  }

  List<String> _extractShowNames(NodeList<Combinator> combinators) {
    return combinators
        .whereType<ShowCombinator>()
        .expand((c) => c.shownNames)
        .map((id) => id.name)
        .toList();
  }

  List<String> _extractHideNames(NodeList<Combinator> combinators) {
    return combinators
        .whereType<HideCombinator>()
        .expand((c) => c.hiddenNames)
        .map((id) => id.name)
        .toList();
  }

  List<ConditionalConfig> _extractConfigurations(
    NodeList<Configuration> configurations,
  ) {
    return configurations
        .map((c) => ConditionalConfig(
              name: c.name.toString(),
              uri: c.uri.stringValue ?? '',
            ))
        .where((c) => c.uri.isNotEmpty)
        .toList();
  }
}
