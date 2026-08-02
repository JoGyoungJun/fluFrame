import 'dart:io' as io;

import 'package:fluframe/src/command_runner.dart';

Future<void> main(List<String> arguments) async {
  io.exitCode = await FluframeCommandRunner().run(arguments);
}
