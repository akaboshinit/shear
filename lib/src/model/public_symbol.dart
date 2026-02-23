/// Kinds of public symbol declarations in Dart.
enum SymbolKind {
  classDecl('class'),
  mixin('mixin'),
  enumDecl('enum'),
  extension('extension'),
  extensionType('extension type'),
  function('function'),
  variable('variable'),
  typedef('typedef');

  const SymbolKind(this.label);

  final String label;
}

/// A public symbol declared in a Dart file.
class PublicSymbol {
  const PublicSymbol({
    required this.name,
    required this.kind,
    required this.filePath,
  });

  final String name;
  final SymbolKind kind;
  final String filePath;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicSymbol &&
          name == other.name &&
          kind == other.kind &&
          filePath == other.filePath;

  @override
  int get hashCode => Object.hash(name, kind, filePath);

  @override
  String toString() => '${kind.label} $name ($filePath)';
}
