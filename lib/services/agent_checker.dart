import 'dart:io';
import '../models/session.dart';

class AgentChecker {
  static Future<Map<AgentType, bool>> checkAvailability() async {
    final results = <AgentType, bool>{};

    for (final agentType in AgentType.values) {
      results[agentType] = await _checkCommand(_getExecutable(agentType));
    }

    return results;
  }

  static Future<bool> isAvailable(AgentType agentType) async {
    return _checkCommand(_getExecutable(agentType));
  }

  static String getInstallHint(AgentType type) {
    switch (type) {
      case AgentType.claude:
        return 'npm install -g @anthropic-ai/claude-cli';
      case AgentType.codex:
        return 'npm install -g @openai/codex-cli';
      case AgentType.opencode:
        return 'See: https://github.com/opencode/opencode';
    }
  }

  static String _getExecutable(AgentType agentType) {
    switch (agentType) {
      case AgentType.claude:
        return 'claude';
      case AgentType.codex:
        return 'codex';
      case AgentType.opencode:
        return 'opencode';
    }
  }

  static Future<bool> _checkCommand(String command) async {
    final result = await Process.run('which', [command]);
    return result.exitCode == 0;
  }
}
