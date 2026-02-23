import '../core/issue.dart';

/// Immutable configuration for a shear analysis run.
class ShearConfig {
  const ShearConfig({
    this.entry = const [],
    this.project = const [],
    this.ignore = const [],
    this.ignoreDependencies = const [],
    this.rules = const {},
    this.includeEntryExports = false,
    this.plugins = const {},
  });

  /// Glob patterns for entry point files.
  final List<String> entry;

  /// Glob patterns defining the project scope.
  final List<String> project;

  /// Glob patterns for files to ignore entirely.
  final List<String> ignore;

  /// Package names to treat as implicitly used.
  final List<String> ignoreDependencies;

  /// Severity rules per issue type.
  final Map<IssueType, Severity> rules;

  /// Whether entry file exports should be checked.
  final bool includeEntryExports;

  /// Plugin enablement flags.
  final Map<String, bool> plugins;

  /// Create a copy with the given fields replaced.
  ShearConfig copyWith({
    List<String>? entry,
    List<String>? project,
    List<String>? ignore,
    List<String>? ignoreDependencies,
    Map<IssueType, Severity>? rules,
    bool? includeEntryExports,
    Map<String, bool>? plugins,
  }) {
    return ShearConfig(
      entry: entry ?? this.entry,
      project: project ?? this.project,
      ignore: ignore ?? this.ignore,
      ignoreDependencies: ignoreDependencies ?? this.ignoreDependencies,
      rules: rules ?? this.rules,
      includeEntryExports: includeEntryExports ?? this.includeEntryExports,
      plugins: plugins ?? this.plugins,
    );
  }

  /// Merge this config with [defaults].
  ///
  /// This config's non-empty values take precedence over defaults.
  ShearConfig mergeWith(ShearConfig defaults) {
    return ShearConfig(
      entry: entry.isNotEmpty ? entry : defaults.entry,
      project: project.isNotEmpty ? project : defaults.project,
      ignore: ignore.isNotEmpty ? ignore : defaults.ignore,
      ignoreDependencies: ignoreDependencies.isNotEmpty
          ? ignoreDependencies
          : defaults.ignoreDependencies,
      rules: {...defaults.rules, ...rules},
      includeEntryExports: includeEntryExports,
      plugins: {...defaults.plugins, ...plugins},
    );
  }
}
