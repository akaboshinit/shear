import 'dart:io';

import 'package:shear/src/cli/cli_runner.dart';

Future<void> main(List<String> arguments) async {
  final runner = ShearCliRunner();
  try {
    final exitCode = await runner.run(arguments) ?? 0;
    exit(exitCode);
  } on Exception catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}
