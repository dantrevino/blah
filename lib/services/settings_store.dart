import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../config/branding.dart';
import '../models/settings.dart';

class SettingsStore {
  static const String _fileName = 'settings.json';

  Future<String> get _settingsPath async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/${Branding.documentsFolder}/$_fileName';
  }

  Future<Settings> load() async {
    final path = await _settingsPath;
    final file = File(path);

    if (!await file.exists()) {
      return Settings();
    }

    try {
      final json = jsonDecode(await file.readAsString());
      return Settings.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      return Settings();
    }
  }

  Future<void> save(Settings settings) async {
    final path = await _settingsPath;
    final file = File(path);

    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
    );
  }

  Future<void> reset() async {
    final path = await _settingsPath;
    final file = File(path);

    if (await file.exists()) {
      await file.delete();
    }
  }
}
