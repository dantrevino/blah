import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../config/branding.dart';
import '../models/chat.dart';

/// Persists chat sessions (message history) to disk.
///
/// Chat files are stored alongside session files:
/// `<documents>/<app>/sessions/<session_id>.chat.json`
class ChatStore {
  Future<String> get _sessionsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/${Branding.documentsFolder}/sessions';
  }

  /// Save a chat session to disk
  Future<void> save(ChatSession chat) async {
    if (chat.messages.isEmpty) return; // Don't save empty chats

    final dir = await _sessionsDir;
    await Directory(dir).create(recursive: true);

    final file = File('$dir/${chat.id}.chat.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(chat.toJson()),
    );
  }

  /// Load a chat session from disk
  Future<ChatSession?> load(String sessionId) async {
    final dir = await _sessionsDir;
    final file = File('$dir/$sessionId.chat.json');

    if (!await file.exists()) return null;

    try {
      final json = jsonDecode(await file.readAsString());
      return ChatSession.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      // If chat file is corrupted, return null (session still valid)
      return null;
    }
  }

  /// Load chat sessions for multiple session IDs
  Future<Map<String, ChatSession>> loadAll(List<String> sessionIds) async {
    final results = <String, ChatSession>{};

    await Future.wait(
      sessionIds.map((id) async {
        final chat = await load(id);
        if (chat != null) {
          results[id] = chat;
        }
      }),
    );

    return results;
  }

  /// Delete a chat session file
  Future<void> delete(String sessionId) async {
    final dir = await _sessionsDir;
    final file = File('$dir/$sessionId.chat.json');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
