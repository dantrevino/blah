import 'package:flutter_test/flutter_test.dart';
import 'package:riot/services/ops/storage_path_resolver.dart';

void main() {
  test('Linux uses XDG_DATA_HOME when set', () {
    final path = resolveAppDataRoot(
      isLinux: true,
      homePath: '/home/dan',
      xdgDataHome: '/home/dan/.data',
      documentsPath: '/home/dan/Documents',
      appFolderName: 'riot',
    );

    expect(path, '/home/dan/.data/riot');
  });

  test('Linux falls back to HOME/.local/share when XDG_DATA_HOME is unset', () {
    final path = resolveAppDataRoot(
      isLinux: true,
      homePath: '/home/dan',
      xdgDataHome: null,
      documentsPath: '/home/dan/Documents',
      appFolderName: 'riot',
    );

    expect(path, '/home/dan/.local/share/riot');
  });

  test('Linux throws when both XDG_DATA_HOME and HOME are unavailable', () {
    expect(
      () => resolveAppDataRoot(
        isLinux: true,
        homePath: null,
        xdgDataHome: null,
        documentsPath: '/home/dan/Documents',
        appFolderName: 'riot',
      ),
      throwsStateError,
    );
  });

  test('Non-linux uses documents path', () {
    final path = resolveAppDataRoot(
      isLinux: false,
      homePath: '/home/dan',
      xdgDataHome: '/ignored',
      documentsPath: '/Users/dan/Documents',
      appFolderName: 'riot',
    );

    expect(path, '/Users/dan/Documents/riot');
  });
}
