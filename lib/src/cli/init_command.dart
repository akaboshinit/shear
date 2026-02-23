import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../config/default_config.dart';
import '../config/shear_config.dart';
import '../core/issue.dart';
import '../plugin/plugin.dart';
import '../plugin/plugin_registry.dart';

/// Command that generates a shear.yaml config file with project defaults.
class InitCommand extends Command<int> {
  InitCommand() {
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Overwrite existing config file.',
      defaultsTo: false,
    );
  }

  @override
  String get name => 'init';

  @override
  String get description =>
      'Generate a shear.yaml config file with project defaults.';

  @override
  Future<int> run() async {
    final projectRoot =
        globalResults?['directory'] as String? ?? Directory.current.path;
    final absolute = p.canonicalize(projectRoot);

    final pubspecFile = File(p.join(absolute, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      stderr.writeln('Error: pubspec.yaml not found in $absolute');
      return 1;
    }

    final configFile = File(p.join(absolute, 'shear.yaml'));
    final force = argResults!['force'] as bool;

    if (configFile.existsSync() && !force) {
      stderr.writeln(
        'shear.yaml already exists. Use --force to overwrite.',
      );
      return 0;
    }

    final config = await DefaultConfig.forProject(absolute);
    final plugins = await PluginRegistry.autoDetect(absolute);

    final yaml = _generateYaml(config, plugins);
    configFile.writeAsStringSync(yaml);

    stderr.writeln('Created shear.yaml in $absolute');
    return 0;
  }

  static const _rulesKeyMap = {
    IssueType.unusedFile: 'unusedFiles',
    IssueType.unusedDependency: 'unusedDependencies',
    IssueType.unusedExport: 'unusedExports',
  };

  static String _generateYaml(
    ShearConfig config,
    List<ShearPlugin> plugins,
  ) {
    final buf = StringBuffer();

    buf.writeln('# Shear configuration');
    buf.writeln('# https://github.com/akaboshinit/shear');
    buf.writeln();

    _writeGlobList(
        buf,
        '# Entry point files — analysis starts from these files',
        'entry',
        config.entry);
    _writeGlobList(buf, '# Project scope — only these files are analyzed',
        'project', config.project);
    _writeGlobList(buf, '# Files to ignore', 'ignore', config.ignore);

    if (config.ignoreDependencies.isNotEmpty) {
      _writeList(buf, '# Dependencies to treat as implicitly used',
          'ignoreDependencies', config.ignoreDependencies);
    }

    buf.writeln('# Severity rules: error | warn | off');
    buf.writeln('rules:');
    for (final entry in _rulesKeyMap.entries) {
      final severity = config.rules[entry.key] ?? Severity.off;
      buf.writeln('  ${entry.value}: ${severity.name}');
    }
    buf.writeln();

    buf.writeln('# Whether to check exports from entry point files');
    buf.writeln('includeEntryExports: ${config.includeEntryExports}');
    buf.writeln();

    if (plugins.isNotEmpty) {
      buf.writeln('# Plugin configuration (auto-detected)');
      buf.writeln('plugins:');
      for (final plugin in plugins) {
        buf.writeln('  ${plugin.name}: true');
      }
      buf.writeln();
    }

    return buf.toString();
  }

  /// Write a YAML list section where values may contain globs that need quoting.
  static void _writeGlobList(
    StringBuffer buf,
    String comment,
    String key,
    List<String> values,
  ) {
    buf.writeln(comment);
    buf.writeln('$key:');
    for (final value in values) {
      buf.writeln('  - ${_quoteIfNeeded(value)}');
    }
    buf.writeln();
  }

  /// Write a plain YAML list section.
  static void _writeList(
    StringBuffer buf,
    String comment,
    String key,
    List<String> values,
  ) {
    buf.writeln(comment);
    buf.writeln('$key:');
    for (final value in values) {
      buf.writeln('  - $value');
    }
    buf.writeln();
  }

  static String _quoteIfNeeded(String value) {
    if (value.contains('*')) {
      return '"$value"';
    }
    return value;
  }
}
