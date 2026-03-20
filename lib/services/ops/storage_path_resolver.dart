String resolveAppDataRoot({
  required bool isLinux,
  required String? homePath,
  required String? xdgDataHome,
  required String documentsPath,
  required String appFolderName,
}) {
  if (isLinux) {
    final xdg = _nonEmpty(xdgDataHome);
    if (xdg != null) {
      return _joinPath(xdg, appFolderName);
    }

    final home = _nonEmpty(homePath);
    if (home != null) {
      return _joinPath(home, '.local/share/$appFolderName');
    }

    throw StateError(
      'Unable to resolve Linux data directory: set XDG_DATA_HOME or HOME',
    );
  }

  return _joinPath(documentsPath, appFolderName);
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

String _joinPath(String a, String b) {
  if (a.endsWith('/')) {
    return '$a$b';
  }
  return '$a/$b';
}
