import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../model/public_symbol.dart';

/// Extracts public symbol declarations from a CompilationUnit.
///
/// Only collects symbols that do not start with '_' (public).
class DeclarationExtractor extends SimpleAstVisitor<void> {
  DeclarationExtractor(this.filePath);

  final String filePath;
  final List<PublicSymbol> symbols = [];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _addIfPublic(node.name.lexeme, SymbolKind.classDecl);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    _addIfPublic(node.name.lexeme, SymbolKind.mixin);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    _addIfPublic(node.name.lexeme, SymbolKind.enumDecl);
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    final name = node.name?.lexeme;
    if (name != null) {
      _addIfPublic(name, SymbolKind.extension);
    }
  }

  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) {
    _addIfPublic(node.name.lexeme, SymbolKind.extensionType);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _addIfPublic(node.name.lexeme, SymbolKind.function);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    for (final variable in node.variables.variables) {
      _addIfPublic(variable.name.lexeme, SymbolKind.variable);
    }
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    _addIfPublic(node.name.lexeme, SymbolKind.typedef);
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    _addIfPublic(node.name.lexeme, SymbolKind.typedef);
  }

  void _addIfPublic(String name, SymbolKind kind) {
    if (!name.startsWith('_')) {
      symbols.add(PublicSymbol(name: name, kind: kind, filePath: filePath));
    }
  }
}
