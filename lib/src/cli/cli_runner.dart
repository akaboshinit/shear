import 'package:args/command_runner.dart';

import 'analyze_command.dart';
import 'delete_command.dart';
import 'init_command.dart';

/// The main CLI runner for shear.
class ShearCliRunner extends CommandRunner<int> {
  ShearCliRunner()
      : super(
          'shear',
          'Find unused files, dependencies, and exports '
              'in Dart & Flutter projects.',
        ) {
    addCommand(AnalyzeCommand());
    addCommand(DeleteCommand());
    addCommand(InitCommand());

    argParser.addOption(
      'directory',
      abbr: 'd',
      help: 'Project root directory.',
      defaultsTo: '.',
    );
  }
}
