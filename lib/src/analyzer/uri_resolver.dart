import 'package:path/path.dart' as p;

/// Result of resolving a Dart URI.
sealed class ResolvedUri {
  const ResolvedUri();
}

/// An internal file within the project.
class InternalUri extends ResolvedUri {
  const InternalUri(this.filePath);

  final String filePath;
}

/// An external package dependency.
class ExternalUri extends ResolvedUri {
  const ExternalUri(this.packageName);

  final String packageName;
}

/// Resolves Dart import/export/part URIs to absolute file paths
/// or external package names.
class UriResolver {
  UriResolver({
    required this.projectRoot,
    required this.packageName,
  });

  final String projectRoot;
  final String packageName;

  /// Resolve a URI from a directive.
  ///
  /// Returns `null` for `dart:` SDK imports (always available).
  /// Returns [InternalUri] for files within this project.
  /// Returns [ExternalUri] for external package dependencies.
  ResolvedUri? resolve(String uri, String fromFile) {
    if (uri.startsWith('dart:')) {
      return null;
    }

    if (uri.startsWith('package:')) {
      return _resolvePackageUri(uri);
    }

    // Relative import
    final dir = p.dirname(fromFile);
    final resolved = p.normalize(p.join(dir, uri));
    return InternalUri(resolved);
  }

  ResolvedUri _resolvePackageUri(String uri) {
    final withoutScheme = uri.substring('package:'.length);
    final slashIndex = withoutScheme.indexOf('/');
    final pkgName = slashIndex == -1
        ? withoutScheme
        : withoutScheme.substring(0, slashIndex);

    if (pkgName == packageName) {
      // Self-referencing package import
      final relativePath =
          slashIndex == -1 ? '' : withoutScheme.substring(slashIndex + 1);
      final filePath = p.normalize(p.join(projectRoot, 'lib', relativePath));
      return InternalUri(filePath);
    }

    return ExternalUri(pkgName);
  }
}
