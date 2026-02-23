/// A plugin that contributes entry files, ignore patterns,
/// and implicit dependency declarations based on framework detection.
abstract class ShearPlugin {
  /// Human-readable plugin name.
  String get name;

  /// Returns true if this plugin should be active for the given project.
  Future<bool> isApplicable(String projectRoot);

  /// Additional entry file patterns contributed by this plugin.
  List<String> get additionalEntryPatterns => const [];

  /// Additional ignore patterns (e.g., generated files).
  List<String> get additionalIgnorePatterns => const [];

  /// Package names that are implicitly used by this framework.
  List<String> get implicitDependencies => const [];
}
