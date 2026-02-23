import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Collects identifier references from a [CompilationUnit] AST.
///
/// Walks the entire AST using [RecursiveAstVisitor] to find identifiers
/// that are actually referenced (not declared), enabling accurate detection
/// of which imported symbols are truly used.
class IdentifierCollector extends RecursiveAstVisitor<void> {
  /// Non-prefixed identifiers referenced in the file (e.g. `Foo`, `myFunc`).
  final Set<String> referencedNames = {};

  /// Prefixed identifier references grouped by prefix name.
  ///
  /// For `import 'x.dart' as p; p.Foo();` this contains `{'p': {'Foo'}}`.
  final Map<String, Set<String>> prefixedReferences = {};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (!node.inDeclarationContext() && !_isConstructorReturnType(node)) {
      referencedNames.add(node.name);
    }
    super.visitSimpleIdentifier(node);
  }

  /// Check if [node] is the return type identifier of a constructor declaration.
  ///
  /// In the Dart AST, `ConstructorDeclaration.returnType` is a
  /// [SimpleIdentifier] whose `inDeclarationContext()` returns false,
  /// even though it simply repeats the enclosing class name and is not
  /// a real reference to the class.  Excluding it prevents the class name
  /// from being spuriously added to [referencedNames].
  static bool _isConstructorReturnType(SimpleIdentifier node) {
    final parent = node.parent;
    return parent is ConstructorDeclaration && identical(parent.returnType, node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final prefixName = node.prefix.name;
    final identifierName = node.identifier.name;
    _addPrefixedReference(prefixName, identifierName);
    referencedNames.add(prefixName);
    // Do not call super to avoid duplicate SimpleIdentifier visits.
  }

  @override
  void visitNamedType(NamedType node) {
    final prefix = node.importPrefix;
    if (prefix != null) {
      _addPrefixedReference(prefix.name.lexeme, node.name2.lexeme);
      referencedNames.add(prefix.name.lexeme);
    } else {
      // NamedType.name2 is a Token, not an AST node, so
      // SimpleIdentifier visitor won't capture it. Add explicitly.
      referencedNames.add(node.name2.lexeme);
    }
    // Always visit children (especially typeArguments like List<Foo>).
    super.visitNamedType(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Without type resolution, `p.myFunction()` is parsed as MethodInvocation
    // rather than as a prefixed identifier reference.
    final target = node.target;
    if (target is SimpleIdentifier) {
      _addPrefixedReference(target.name, node.methodName.name);
    }
    super.visitMethodInvocation(node);
  }

  void _addPrefixedReference(String prefix, String name) {
    (prefixedReferences[prefix] ??= {}).add(name);
  }
}
