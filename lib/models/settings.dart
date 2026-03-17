class Settings {
  final AppSettings app;
  final TerminalSettings terminal;
  final AgentSettings agents;

  Settings({
    AppSettings? app,
    TerminalSettings? terminal,
    AgentSettings? agents,
  })  : app = app ?? AppSettings.defaults(),
        terminal = terminal ?? TerminalSettings.defaults(),
        agents = agents ?? AgentSettings.defaults();

  Settings copyWith({
    AppSettings? app,
    TerminalSettings? terminal,
    AgentSettings? agents,
  }) {
    return Settings(
      app: app ?? this.app,
      terminal: terminal ?? this.terminal,
      agents: agents ?? this.agents,
    );
  }

  Map<String, dynamic> toJson() => {
        'app': app.toJson(),
        'terminal': terminal.toJson(),
        'agents': agents.toJson(),
      };

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      app: json['app'] != null ? AppSettings.fromJson(json['app']) : null,
      terminal: json['terminal'] != null
          ? TerminalSettings.fromJson(json['terminal'])
          : null,
      agents: json['agents'] != null
          ? AgentSettings.fromJson(json['agents'])
          : null,
    );
  }
}

class AppSettings {
  final String branchPrefix;
  final bool autoCleanupWorktrees;
  final bool confirmOnClose;

  AppSettings({
    required this.branchPrefix,
    required this.autoCleanupWorktrees,
    required this.confirmOnClose,
  });

  factory AppSettings.defaults() => AppSettings(
        branchPrefix: 'agent',
        autoCleanupWorktrees: true,
        confirmOnClose: true,
      );

  Map<String, dynamic> toJson() => {
        'branchPrefix': branchPrefix,
        'autoCleanupWorktrees': autoCleanupWorktrees,
        'confirmOnClose': confirmOnClose,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      branchPrefix: json['branchPrefix'] ?? 'agent',
      autoCleanupWorktrees: json['autoCleanupWorktrees'] ?? true,
      confirmOnClose: json['confirmOnClose'] ?? true,
    );
  }

  AppSettings copyWith({
    String? branchPrefix,
    bool? autoCleanupWorktrees,
    bool? confirmOnClose,
  }) {
    return AppSettings(
      branchPrefix: branchPrefix ?? this.branchPrefix,
      autoCleanupWorktrees: autoCleanupWorktrees ?? this.autoCleanupWorktrees,
      confirmOnClose: confirmOnClose ?? this.confirmOnClose,
    );
  }
}

class TerminalSettings {
  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final String themeName;
  final bool ligaturesEnabled;
  final int scrollbackLines;
  final bool cursorBlink;

  TerminalSettings({
    required this.fontFamily,
    required this.fontSize,
    required this.lineHeight,
    required this.themeName,
    required this.ligaturesEnabled,
    required this.scrollbackLines,
    required this.cursorBlink,
  });

  factory TerminalSettings.defaults() => TerminalSettings(
        fontFamily: 'JetBrains Mono',
        fontSize: 14,
        lineHeight: 1.4,
        themeName: 'dark',
        ligaturesEnabled: true,
        scrollbackLines: 10000,
        cursorBlink: true,
      );

  Map<String, dynamic> toJson() => {
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'themeName': themeName,
        'ligaturesEnabled': ligaturesEnabled,
        'scrollbackLines': scrollbackLines,
        'cursorBlink': cursorBlink,
      };

  factory TerminalSettings.fromJson(Map<String, dynamic> json) {
    return TerminalSettings(
      fontFamily: json['fontFamily'] ?? 'JetBrains Mono',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.4,
      themeName: json['themeName'] ?? 'dark',
      ligaturesEnabled: json['ligaturesEnabled'] ?? true,
      scrollbackLines: json['scrollbackLines'] ?? 10000,
      cursorBlink: json['cursorBlink'] ?? true,
    );
  }

  TerminalSettings copyWith({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    String? themeName,
    bool? ligaturesEnabled,
    int? scrollbackLines,
    bool? cursorBlink,
  }) {
    return TerminalSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      themeName: themeName ?? this.themeName,
      ligaturesEnabled: ligaturesEnabled ?? this.ligaturesEnabled,
      scrollbackLines: scrollbackLines ?? this.scrollbackLines,
      cursorBlink: cursorBlink ?? this.cursorBlink,
    );
  }
}

class AgentSettings {
  final Map<String, AgentConfig> configs;

  AgentSettings({required this.configs});

  factory AgentSettings.defaults() => AgentSettings(
        configs: {
          'claude': AgentConfig(
            executable: 'claude',
            defaultArgs: ['--session-id'],
            env: {},
          ),
          'codex': AgentConfig(
            executable: 'codex',
            defaultArgs: ['--session-id'],
            env: {},
          ),
          'opencode': AgentConfig(
            executable: 'opencode',
            defaultArgs: ['--session-id'],
            env: {},
          ),
        },
      );

  AgentConfig getConfig(String agentType) {
    return configs[agentType] ?? configs['claude']!;
  }

  Map<String, dynamic> toJson() => {
        'configs': configs.map((key, value) => MapEntry(key, value.toJson())),
      };

  factory AgentSettings.fromJson(Map<String, dynamic> json) {
    final configs = <String, AgentConfig>{};
    if (json['configs'] != null) {
      (json['configs'] as Map<String, dynamic>).forEach((key, value) {
        configs[key] = AgentConfig.fromJson(value as Map<String, dynamic>);
      });
    }
    return AgentSettings(configs: configs);
  }
}

class AgentConfig {
  final String executable;
  final List<String> defaultArgs;
  final Map<String, String> env;
  final String? configPath;

  AgentConfig({
    required this.executable,
    required this.defaultArgs,
    required this.env,
    this.configPath,
  });

  Map<String, dynamic> toJson() => {
        'executable': executable,
        'defaultArgs': defaultArgs,
        'env': env,
        'configPath': configPath,
      };

  factory AgentConfig.fromJson(Map<String, dynamic> json) {
    final env = <String, String>{};
    if (json['env'] != null) {
      (json['env'] as Map<String, dynamic>)
          .forEach((key, value) => env[key] = value as String);
    }
    return AgentConfig(
      executable: json['executable'] ?? 'claude',
      defaultArgs: (json['defaultArgs'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          ['--session-id'],
      env: env,
      configPath: json['configPath'] as String?,
    );
  }
}
