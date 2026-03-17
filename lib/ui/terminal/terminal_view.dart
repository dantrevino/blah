import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

class BlahTerminalView extends StatefulWidget {
  final Terminal terminal;
  final void Function(String)? onOutput;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? fontFamily;
  final double? fontSize;

  const BlahTerminalView({
    required this.terminal,
    this.onOutput,
    this.backgroundColor,
    this.foregroundColor,
    this.fontFamily,
    this.fontSize,
    super.key,
  });

  @override
  State<BlahTerminalView> createState() => _BlahTerminalViewState();
}

class _BlahTerminalViewState extends State<BlahTerminalView> {
  late final TerminalController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TerminalController();

    if (widget.onOutput != null) {
      widget.terminal.onOutput = widget.onOutput;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor ?? const Color(0xFF0A0A0A),
      child: TerminalView(
        widget.terminal,
        controller: _controller,
        theme: _buildTheme(),
        textStyle: TerminalStyle(
          fontFamily: widget.fontFamily ?? 'JetBrainsMono Nerd Font',
          fontSize: widget.fontSize ?? 14,
        ),
      ),
    );
  }

  TerminalTheme _buildTheme() {
    final bg = widget.backgroundColor ?? const Color(0xFF0A0A0A);
    final fg = widget.foregroundColor ?? const Color(0xFFF0F0F0);

    return TerminalTheme(
      cursor: fg,
      selection: fg.withValues(alpha: 0.3),
      foreground: fg,
      background: bg,
      black: const Color(0xFF000000),
      red: const Color(0xFFCD3131),
      green: const Color(0xFF0DBC79),
      yellow: const Color(0xFFE5E510),
      blue: const Color(0xFF2472C8),
      magenta: const Color(0xFFBC3FBC),
      cyan: const Color(0xFF11A8CD),
      white: const Color(0xFFE5E5E5),
      brightBlack: const Color(0xFF666666),
      brightRed: const Color(0xFFF14C4C),
      brightGreen: const Color(0xFF23D18B),
      brightYellow: const Color(0xFFF5F543),
      brightBlue: const Color(0xFF3B8EEA),
      brightMagenta: const Color(0xFFD670D6),
      brightCyan: const Color(0xFF29B8DB),
      brightWhite: const Color(0xFFFFFFFF),
      searchHitBackground: const Color(0xFFFFFF2B),
      searchHitBackgroundCurrent: const Color(0xFF31FF26),
      searchHitForeground: const Color(0xFF000000),
    );
  }
}
