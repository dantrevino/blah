import 'package:flutter_test/flutter_test.dart';
import 'package:riot/models/settings.dart';

void main() {
  test('app settings include debug mode default and json roundtrip', () {
    final defaults = AppSettings.defaults();
    expect(defaults.debugMode, isFalse);

    final encoded = defaults.copyWith(debugMode: true).toJson();
    final decoded = AppSettings.fromJson(encoded);
    expect(decoded.debugMode, isTrue);
  });
}
