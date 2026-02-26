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
    final name = node.name.lexeme;
    if (name.startsWith('_')) return;

    final members = _extractClassMembers(node.members);
    symbols.add(PublicSymbol(
      name: name,
      kind: SymbolKind.classDecl,
      filePath: filePath,
      memberNames: members,
    ));
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    final name = node.name.lexeme;
    if (name.startsWith('_')) return;

    final members = _extractClassMembers(node.members);
    symbols.add(PublicSymbol(
      name: name,
      kind: SymbolKind.mixin,
      filePath: filePath,
      memberNames: members,
    ));
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    final name = node.name.lexeme;
    if (name.startsWith('_')) return;

    final members = node.constants
        .map((c) => c.name.lexeme)
        .where((n) => !n.startsWith('_'))
        .toList();

    symbols.add(PublicSymbol(
      name: name,
      kind: SymbolKind.enumDecl,
      filePath: filePath,
      memberNames: members,
    ));
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

  List<String> _extractClassMembers(NodeList<ClassMember> members) {
    final result = <String>[];
    for (final member in members) {
      if (member is MethodDeclaration) {
        if (_hasOverrideAnnotation(member)) continue;
        if (member.name.lexeme.startsWith('_')) continue;
        if (member.isOperator) continue;
        result.add(member.name.lexeme);
      } else if (member is FieldDeclaration) {
        if (!member.isStatic) continue;
        for (final v in member.fields.variables) {
          if (!v.name.lexeme.startsWith('_')) result.add(v.name.lexeme);
        }
      } else if (member is ConstructorDeclaration) {
        final ctorName = member.name?.lexeme;
        if (ctorName != null && !ctorName.startsWith('_')) {
          result.add(ctorName);
        }
      }
    }
    return result;
  }

  bool _hasOverrideAnnotation(AnnotatedNode node) {
    return node.metadata.any((a) => a.name.name == 'override');
  }
}
