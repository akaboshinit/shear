import 'build_runner_plugin.dart';
import 'flutter_plugin.dart';
import 'plugin.dart';

/// Registry that auto-detects applicable plugins for a project.
class PluginRegistry {
  PluginRegistry._();

  static final List<ShearPlugin> _builtInPlugins = [
    FlutterPlugin(),
    BuildRunnerPlugin(),
  ];

  /// Auto-detect which plugins apply to the given project.
  static Future<List<ShearPlugin>> autoDetect(String projectRoot) async {
    final active = <ShearPlugin>[];
    for (final plugin in _builtInPlugins) {
      if (await plugin.isApplicable(projectRoot)) {
        active.add(plugin);
      }
    }
    return active;
  }
}
