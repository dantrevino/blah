/// Chat message types for the Conductor-style UI
enum MessageRole {
  user,
  assistant,
  system,
  tool,
}

enum MessageStatus {
  sending,
  sent,
  streaming,
  complete,
  error,
}

/// Represents a tool invocation shown in the chat
class ToolUse {
  final String id;
  final String name;
  final Map<String, dynamic> input;
  final String? output;
  final bool isComplete;

  const ToolUse({
    required this.id,
    required this.name,
    required this.input,
    this.output,
    this.isComplete = false,
  });

  ToolUse copyWith({
    String? id,
    String? name,
    Map<String, dynamic>? input,
    String? output,
    bool? isComplete,
  }) {
    return ToolUse(
      id: id ?? this.id,
      name: name ?? this.name,
      input: input ?? this.input,
      output: output ?? this.output,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

/// A single message in the chat
class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final MessageStatus status;
  final List<ToolUse> toolUses;
  final String? error;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.status = MessageStatus.complete,
    this.toolUses = const [],
    this.error,
  });

  ChatMessage copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    MessageStatus? status,
    List<ToolUse>? toolUses,
    String? error,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      toolUses: toolUses ?? this.toolUses,
      error: error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'status': status.name,
        'toolUses': toolUses
            .map((t) => {
                  'id': t.id,
                  'name': t.name,
                  'input': t.input,
                  'output': t.output,
                  'isComplete': t.isComplete,
                })
            .toList(),
        'error': error,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      role: MessageRole.values.byName(json['role'] as String),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: MessageStatus.values.byName(json['status'] as String),
      toolUses: (json['toolUses'] as List<dynamic>?)
              ?.map((t) => ToolUse(
                    id: t['id'] as String,
                    name: t['name'] as String,
                    input: Map<String, dynamic>.from(t['input'] as Map),
                    output: t['output'] as String?,
                    isComplete: t['isComplete'] as bool? ?? false,
                  ))
              .toList() ??
          [],
      error: json['error'] as String?,
    );
  }
}

/// Chat session containing messages and metadata
class ChatSession {
  final String id;
  final List<ChatMessage> messages;
  final bool isAgentTyping;
  final String? currentStreamingMessageId;

  const ChatSession({
    required this.id,
    this.messages = const [],
    this.isAgentTyping = false,
    this.currentStreamingMessageId,
  });

  ChatSession copyWith({
    String? id,
    List<ChatMessage>? messages,
    bool? isAgentTyping,
    String? currentStreamingMessageId,
  }) {
    return ChatSession(
      id: id ?? this.id,
      messages: messages ?? this.messages,
      isAgentTyping: isAgentTyping ?? this.isAgentTyping,
      currentStreamingMessageId:
          currentStreamingMessageId ?? this.currentStreamingMessageId,
    );
  }

  /// Add a message to the session
  ChatSession addMessage(ChatMessage message) {
    return copyWith(messages: [...messages, message]);
  }

  /// Update an existing message (for streaming)
  ChatSession updateMessage(String messageId, ChatMessage updated) {
    return copyWith(
      messages: messages.map((m) => m.id == messageId ? updated : m).toList(),
    );
  }

  /// Serialize to JSON for persistence
  /// Only persists messages, not transient state (isAgentTyping, currentStreamingMessageId)
  Map<String, dynamic> toJson() => {
        'id': id,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  /// Deserialize from JSON
  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) =>
                  ChatMessage.fromJson(Map<String, dynamic>.from(m as Map)))
              .toList() ??
          [],
      // Transient state defaults to false/null
      isAgentTyping: false,
      currentStreamingMessageId: null,
    );
  }
}
