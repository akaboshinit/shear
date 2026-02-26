import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../core/issue.dart';
import 'default_config.dart';
import 'shear_config.dart';

/// Loads shear configuration from a YAML file.
class ConfigLoader {
  ConfigLoader._();

  /// Load config from the project root.
  ///
  /// Looks for `shear.yaml` in [projectRoot]. If not found,
  /// returns default config for the project.
  static Future<ShearConfig> load(String projectRoot) async {
    final defaults = await DefaultConfig.forProject(projectRoot);

    final configFile = _findConfigFile(projectRoot);
    if (configFile == null) {
      return defaults;
    }

    final yamlContent = await configFile.readAsString();
    final yamlMap = loadYaml(yamlContent);

    if (yamlMap is! YamlMap) {
      return defaults;
    }

    final userConfig = _parseConfig(yamlMap);
    return userConfig.mergeWith(defaults);
  }

  static File? _findConfigFile(String projectRoot) {
    const configNames = [
      'shear.yaml',
      'shear.yml',
      '.shear.yaml',
      '.shear.yml',
    ];

    for (final name in configNames) {
      final file = File(p.join(projectRoot, name));
      if (file.existsSync()) {
        return file;
      }
    }
    return null;
  }

  static ShearConfig _parseConfig(YamlMap yaml) {
    return ShearConfig(
      entry: _parseStringList(yaml['entry']),
      project: _parseStringList(yaml['project']),
      ignore: _parseStringList(yaml['ignore']),
      ignoreDependencies: _parseStringList(yaml['ignoreDependencies']),
      rules: _parseRules(yaml['rules']),
      includeEntryExports: yaml['includeEntryExports'] as bool? ?? false,
      plugins: _parsePlugins(yaml['plugins']),
    );
  }

  static List<String> _parseStringList(Object? value) {
    if (value is YamlList) {
      return value.cast<String>().toList();
    }
    return const [];
  }

  static Map<IssueType, Severity> _parseRules(Object? value) {
    if (value is! YamlMap) return const {};

    final rules = <IssueType, Severity>{};
    final mapping = {
      'unusedFiles': IssueType.unusedFile,
      'unusedDependencies': IssueType.unusedDependency,
      'unlistedDependencies': IssueType.unlistedDependency,
      'unusedExports': IssueType.unusedExport,
      'unusedEnumMembers': IssueType.unusedEnumMember,
      'unusedClassMembers': IssueType.unusedClassMember,
    };

    for (final entry in mapping.entries) {
      final severityStr = value[entry.key] as String?;
      if (severityStr != null) {
        rules[entry.value] = Severity.fromString(severityStr);
      }
    }
    return rules;
  }

  static Map<String, bool> _parsePlugins(Object? value) {
    if (value is! YamlMap) return const {};

    final plugins = <String, bool>{};
    for (final entry in value.entries) {
      plugins[entry.key as String] = entry.value as bool;
    }
    return plugins;
  }
}
