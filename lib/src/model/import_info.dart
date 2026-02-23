/// Categories of Dart URI.
enum UriKind { dart, package, relative }

/// Configuration for conditional imports.
class ConditionalConfig {
  const ConditionalConfig({
    required this.name,
    required this.uri,
  });

  /// The condition name, e.g. "dart.library.io".
  final String name;

  /// The alternative URI when the condition is met.
  final String uri;
}

/// Shared URI classification logic for import/export directives.
mixin DirectiveUri {
  String get uri;

  UriKind get uriKind {
    if (uri.startsWith('dart:')) return UriKind.dart;
    if (uri.startsWith('package:')) return UriKind.package;
    return UriKind.relative;
  }

  /// Extract package name from 'package:foo/bar.dart' -> 'foo'.
  String? get packageName {
    if (uriKind != UriKind.package) return null;
    final withoutScheme = uri.substring('package:'.length);
    final slashIndex = withoutScheme.indexOf('/');
    return slashIndex == -1
        ? withoutScheme
        : withoutScheme.substring(0, slashIndex);
  }
}

/// Parsed information from an import directive.
class ImportInfo with DirectiveUri {
  const ImportInfo({
    required this.uri,
    this.prefix,
    this.isDeferred = false,
    this.showNames = const [],
    this.hideNames = const [],
    this.configurations = const [],
  });

  @override
  final String uri;
  final String? prefix;
  final bool isDeferred;
  final List<String> showNames;
  final List<String> hideNames;
  final List<ConditionalConfig> configurations;
}

/// Parsed information from an export directive.
class ExportInfo with DirectiveUri {
  const ExportInfo({
    required this.uri,
    this.showNames = const [],
    this.hideNames = const [],
    this.configurations = const [],
  });

  @override
  final String uri;
  final List<String> showNames;
  final List<String> hideNames;
  final List<ConditionalConfig> configurations;
}

/// Parsed information from a part directive.
class PartInfo {
  const PartInfo({required this.uri});

  final String uri;
}

/// Parsed information from a part-of directive.
class PartOfInfo {
  const PartOfInfo({this.uri, this.libraryName});

  /// URI-based part of: `part of 'foo.dart';`
  final String? uri;

  /// Legacy name-based part of: `part of my_lib;`
  final String? libraryName;
}
