import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

/// A slide-out terminal panel that runs a shell in the given working directory
class TerminalPanel extends StatefulWidget {
  final String workingDirectory;
  final VoidCallback onClose;

  const TerminalPanel({
    required this.workingDirectory,
    required this.onClose,
    super.key,
  });

  @override
  State<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends State<TerminalPanel> {
  late final Terminal _terminal;
  late final Pty _pty;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(
      maxLines: 10000,
    );
    _startPty();
  }

  void _startPty() {
    // Determine shell to use
    final rawShell = Platform.environment['SHELL'] ?? '/bin/bash';
    final shell = rawShell.split(' ').first;
    final shellName = shell.split('/').last;

    // Use shell args that avoid loading heavy user prompt customizations
    // (which can be extremely long inside worktree paths).
    final shellArgs = switch (shellName) {
      'zsh' => const ['-f'],
      'bash' => const ['--noprofile', '--norc'],
      _ => const <String>[],
    };

    // Set up environment with proper TERM for color/escape sequence support
    final environment = Map<String, String>.from(Platform.environment);
    environment['TERM'] = 'xterm-256color';

    // Force a minimal, deterministic prompt so long user shell themes do not
    // overwhelm the embedded terminal UI.
    final promptLabel = _buildPromptLabel(widget.workingDirectory);
    environment['PS1'] = '$promptLabel \$ ';
    environment['PROMPT'] = '$promptLabel > ';
    environment['RPROMPT'] = '';

    _pty = Pty.start(
      shell,
      arguments: shellArgs,
      workingDirectory: widget.workingDirectory,
      environment: environment,
    );

    // Connect PTY output to terminal
    _pty.output.listen((data) {
      _terminal.write(utf8.decode(data, allowMalformed: true));
    });

    // Connect terminal input to PTY
    _terminal.onOutput = (data) {
      _pty.write(utf8.encode(data));
    };

    // Handle terminal resize
    _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      _pty.resize(height, width);
    };
  }

  String _buildPromptLabel(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      return 'riot';
    }

    final tail = segments.last;
    if (tail.length >= 8) {
      return 'riot:${tail.substring(0, 8)}';
    }
    return 'riot:$tail';
  }

  @override
  void dispose() {
    _pty.kill();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark terminal background
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          _TerminalHeader(
            workingDirectory: widget.workingDirectory,
            onClose: widget.onClose,
          ),
          // Terminal view
          Expanded(
            child: TerminalView(
              _terminal,
              textStyle: const TerminalStyle(
                fontFamily: 'JetBrainsMono Nerd Font',
                fontSize: 13,
              ),
              theme: _terminalTheme,
              autofocus: true,
            ),
          ),
        ],
      ),
    );
  }

  // Custom terminal theme matching riot.ai dark theme
  TerminalTheme get _terminalTheme => const TerminalTheme(
        cursor: Color(0xFFD946EF), // Boom fuchsia cursor
        selection: Color(0x40D946EF),
        foreground: Color(0xFFE0E0E0),
        background: Color(0xFF1E1E1E),
        black: Color(0xFF1E1E1E),
        red: Color(0xFFE06C75),
        green: Color(0xFF98C379),
        yellow: Color(0xFFE5C07B),
        blue: Color(0xFF61AFEF),
        magenta: Color(0xFFC678DD),
        cyan: Color(0xFF56B6C2),
        white: Color(0xFFABB2BF),
        brightBlack: Color(0xFF5C6370),
        brightRed: Color(0xFFE06C75),
        brightGreen: Color(0xFF98C379),
        brightYellow: Color(0xFFE5C07B),
        brightBlue: Color(0xFF61AFEF),
        brightMagenta: Color(0xFFC678DD),
        brightCyan: Color(0xFF56B6C2),
        brightWhite: Color(0xFFFFFFFF),
        searchHitBackground: Color(0xFFE5C07B),
        searchHitBackgroundCurrent: Color(0xFFE06C75),
        searchHitForeground: Color(0xFF1E1E1E),
      );
}

/// Terminal panel header with title and close button
class _TerminalHeader extends StatelessWidget {
  final String workingDirectory;
  final VoidCallback onClose;

  const _TerminalHeader({
    required this.workingDirectory,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.terminal,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Terminal',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _shortenPath(workingDirectory),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontFamily: 'JetBrainsMono Nerd Font',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClose,
            tooltip: 'Close terminal (Ctrl+`)',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  String _shortenPath(String path) {
    final parts = path.split('/');
    if (parts.length > 3) {
      return '.../${parts.sublist(parts.length - 3).join('/')}';
    }
    return path;
  }
}
