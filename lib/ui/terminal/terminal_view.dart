import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libghostty/libghostty.dart' hide KeyEvent;

class TerminalView extends StatefulWidget {
  final Terminal terminal;
  final void Function(String)? onInput;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? fontFamily;
  final double? fontSize;

  const TerminalView({
    required this.terminal,
    this.onInput,
    this.backgroundColor,
    this.foregroundColor,
    this.fontFamily,
    this.fontSize,
    super.key,
  });

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  late final FocusNode _focusNode;
  late final TextEditingController _inputBuffer;
  String _currentLine = '';

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _inputBuffer = TextEditingController();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _inputBuffer.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      widget.onInput?.call('$_currentLine\n');
      _currentLine = '';
    } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_currentLine.isNotEmpty) {
        _currentLine = _currentLine.substring(0, _currentLine.length - 1);
        widget.onInput?.call('\x7f');
      }
    } else if (event.character != null) {
      _currentLine += event.character!;
      widget.onInput?.call(event.character!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Container(
          color: widget.backgroundColor ?? const Color(0xFF0A0A0A),
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            child: _buildTerminalContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildTerminalContent() {
    final buffer = StringBuffer();

    for (var row = 0; row < widget.terminal.screen.rows; row++) {
      final line = widget.terminal.screen.lineAt(row);
      buffer.writeln(line.text);
    }

    return SelectableText(
      buffer.toString(),
      style: TextStyle(
        fontFamily: widget.fontFamily ?? 'JetBrains Mono',
        fontSize: widget.fontSize ?? 14,
        color: widget.foregroundColor ?? const Color(0xFFF0F0F0),
        fontFeatures: const [
          FontFeature.tabularFigures(),
        ],
      ),
    );
  }
}
