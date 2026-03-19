import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../config/branding.dart';
import '../models/session.dart';

class SessionStore {
  Future<String> get _sessionsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/${Branding.documentsFolder}/sessions';
  }

  Future<void> save(Session session) async {
    final dir = await _sessionsDir;
    await Directory(dir).create(recursive: true);

    final file = File('$dir/${session.id}.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(session.toJson()),
    );
  }

  Future<Session?> load(String sessionId) async {
    final dir = await _sessionsDir;
    final file = File('$dir/$sessionId.json');

    if (!await file.exists()) return null;

    try {
      final json = jsonDecode(await file.readAsString());
      return Session.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  Future<List<Session>> loadAll() async {
    final dir = await _sessionsDir;
    final directory = Directory(dir);

    if (!await directory.exists()) return [];

    final files = await directory
        .list()
        .where((entity) => entity.path.endsWith('.json'))
        .toList();

    final sessions = await Future.wait(
      files.map((file) async {
        try {
          final json = jsonDecode(await File(file.path).readAsString());
          return Session.fromJson(json as Map<String, dynamic>);
        } catch (e) {
          return null;
        }
      }),
    );

    return sessions.whereType<Session>().toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> delete(String sessionId) async {
    final dir = await _sessionsDir;
    final file = File('$dir/$sessionId.json');
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> markCorrupted(String sessionId) async {
    final dir = await _sessionsDir;
    final file = File('$dir/$sessionId.json');
    if (await file.exists()) {
      final corruptedFile = File('$dir/$sessionId.corrupted.json');
      await file.rename(corruptedFile.path);
    }
  }
}
