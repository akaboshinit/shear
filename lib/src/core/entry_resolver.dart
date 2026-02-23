import 'dart:io';

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;

import '../config/shear_config.dart';
import '../graph/module_graph.dart';
import '../model/public_symbol.dart';
import '../plugin/plugin.dart';

/// Resolves entry point files for the project.
///
/// Entry points are the roots of the dependency tree. Files reachable
/// from entry points are considered "used".
class EntryResolver {
  const EntryResolver({
    required this.config,
    required this.projectRoot,
    required this.plugins,
  });

  final ShearConfig config;
  final String projectRoot;
  final List<ShearPlugin> plugins;

  /// Resolve all entry point file paths.
  Future<Set<String>> resolve(ModuleGraph graph) async {
    final entryFiles = <String>{};

    final allPatterns = [
      ...config.entry,
      for (final plugin in plugins) ...plugin.additionalEntryPatterns,
    ];
    for (final pattern in allPatterns) {
      final glob = Glob(pattern);
      await for (final entity in glob.list(root: projectRoot)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          entryFiles.add(p.normalize(entity.path));
        }
      }
    }

    for (final entry in graph.files.entries) {
      final hasMain = entry.value.publicSymbols.any(
        (s) => s.name == 'main' && s.kind == SymbolKind.function,
      );
      if (hasMain) {
        entryFiles.add(entry.key);
      }
    }

    return entryFiles;
  }
}
