import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../config/branding.dart';
import '../../models/chat.dart';
import '../../models/session.dart';

/// Main chat view displaying messages and input
class ChatView extends StatefulWidget {
  final List<ChatMessage> messages;
  final bool isAgentTyping;
  final AgentType agentType;
  final void Function(String message) onSendMessage;
  final VoidCallback? onStop;

  const ChatView({
    required this.messages,
    required this.isAgentTyping,
    required this.agentType,
    required this.onSendMessage,
    this.onStop,
    super.key,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void didUpdateWidget(ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll when new messages arrive
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSendMessage(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Messages list
        Expanded(
          child: widget.messages.isEmpty
              ? _EmptyChat(
                  agentType: widget.agentType,
                  isAgentTyping: widget.isAgentTyping,
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      widget.messages.length + (widget.isAgentTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == widget.messages.length &&
                        widget.isAgentTyping) {
                      return _TypingIndicator(agentType: widget.agentType);
                    }
                    return _MessageBubble(
                      message: widget.messages[index],
                      agentType: widget.agentType,
                    );
                  },
                ),
        ),
        // Input area
        _ChatInput(
          controller: _controller,
          focusNode: _focusNode,
          isAgentTyping: widget.isAgentTyping,
          onSend: _handleSend,
          onStop: widget.onStop,
        ),
      ],
    );
  }
}

/// Empty state when no messages
class _EmptyChat extends StatelessWidget {
  final AgentType agentType;
  final bool isAgentTyping;

  const _EmptyChat({required this.agentType, required this.isAgentTyping});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            Branding.appIconPath,
            width: 64,
            height: 64,
            colorFilter: ColorFilter.mode(
              Theme.of(context).colorScheme.outline,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isAgentTyping
                ? '${agentType.name} is thinking...'
                : 'Start a conversation with ${agentType.name}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          if (isAgentTyping)
            _StreamingDots()
          else
            Text(
              'Type a message below to begin',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
        ],
      ),
    );
  }
}

/// Single message bubble
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final AgentType agentType;

  const _MessageBubble({
    required this.message,
    required this.agentType,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final isSystem = message.role == MessageRole.system;
    final theme = Theme.of(context);

    if (isSystem) {
      return _SystemMessage(message: message);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          _Avatar(isUser: isUser, agentType: agentType),
          const SizedBox(width: 12),
          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Role label
                Text(
                  isUser ? 'You' : agentType.name,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                // Message text
                if (message.content.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      message.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isUser
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                // Tool uses
                if (message.toolUses.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...message.toolUses.map(
                    (tool) => _ToolUseCard(toolUse: tool),
                  ),
                ],
                // Streaming indicator
                if (message.status == MessageStatus.streaming)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _StreamingDots(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar for user or agent
class _Avatar extends StatelessWidget {
  final bool isUser;
  final AgentType agentType;

  const _Avatar({required this.isUser, required this.agentType});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isUser) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: theme.colorScheme.primary,
        child: Icon(
          Icons.person,
          size: 18,
          color: theme.colorScheme.onPrimary,
        ),
      );
    }

    return CircleAvatar(
      radius: 16,
      backgroundColor: theme.colorScheme.secondaryContainer,
      child: SvgPicture.asset(
        Branding.appIconPath,
        width: 18,
        height: 18,
        colorFilter: ColorFilter.mode(
          Branding.primaryColor,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

/// System message (errors, notifications)
class _SystemMessage extends StatelessWidget {
  final ChatMessage message;

  const _SystemMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError = message.status == MessageStatus.error;
    final isDebug = message.content.startsWith('debug> ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isError
                ? theme.colorScheme.errorContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SelectableText(
                  message.content,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isError
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.outline,
                  ),
                ),
              ),
              if (isDebug) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.copy, size: 14),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Copy command',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: message.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Debug command copied')),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tool use display card
class _ToolUseCard extends StatelessWidget {
  final ToolUse toolUse;

  const _ToolUseCard({required this.toolUse});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            toolUse.isComplete ? Icons.check_circle : Icons.pending,
            size: 16,
            color: toolUse.isComplete
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  toolUse.name,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'JetBrainsMono Nerd Font',
                  ),
                ),
                if (toolUse.input.isNotEmpty)
                  Text(
                    _formatToolInput(toolUse.input),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontFamily: 'JetBrainsMono Nerd Font',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatToolInput(Map<String, dynamic> input) {
    // Show file path if present, otherwise first key-value
    if (input.containsKey('file')) return input['file'].toString();
    if (input.containsKey('path')) return input['path'].toString();
    if (input.containsKey('command')) return input['command'].toString();
    if (input.isEmpty) return '';
    final firstKey = input.keys.first;
    return '$firstKey: ${input[firstKey]}';
  }
}

/// Typing indicator dots
class _TypingIndicator extends StatelessWidget {
  final AgentType agentType;

  const _TypingIndicator({required this.agentType});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(isUser: false, agentType: agentType),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                agentType.name,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              _StreamingDots(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Animated streaming dots
class _StreamingDots extends StatefulWidget {
  @override
  State<_StreamingDots> createState() => _StreamingDotsState();
}

class _StreamingDotsState extends State<_StreamingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = ((_controller.value + delay) % 1.0);
            final opacity = (value < 0.5 ? value * 2 : (1 - value) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: 0.3 + (opacity * 0.7),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Branding.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Chat input field
class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isAgentTyping;
  final VoidCallback onSend;
  final VoidCallback? onStop;

  const _ChatInput({
    required this.controller,
    required this.focusNode,
    required this.isAgentTyping,
    required this.onSend,
    this.onStop,
  });

  void _handleKeyDown(KeyEvent event, BuildContext context) {
    // Submit on Enter (without Shift)
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      onSend();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(
                    color: Branding.primaryColor,
                    width: 3,
                  ),
                ),
              ),
              child: KeyboardListener(
                focusNode: FocusNode(),
                onKeyEvent: (event) => _handleKeyDown(event, context),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 3,
                  maxLines: 8,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText:
                        'Type a message... (Enter to send, Shift+Enter for newline)',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Only show stop button when agent is typing
          if (isAgentTyping && onStop != null) ...[
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onStop,
              icon: const Icon(Icons.stop),
              tooltip: 'Stop',
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.errorContainer,
                foregroundColor: theme.colorScheme.onErrorContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
