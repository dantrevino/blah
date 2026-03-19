import 'dart:io';

class CommandOutcome {
  final int exitCode;
  final String stdout;
  final String stderr;

  const CommandOutcome(this.exitCode, this.stdout, this.stderr);

  bool get ok => exitCode == 0;
}

class CommandRunner {
  Future<CommandOutcome> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
  }) async {
    final result = await Process.run(
      executable,
      args,
      workingDirectory: workingDirectory,
    );

    return CommandOutcome(
      result.exitCode,
      result.stdout.toString(),
      result.stderr.toString(),
    );
  }
}
