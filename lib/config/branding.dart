import 'package:flutter/material.dart';

/// Centralized branding configuration for the app.
///
/// Change these values to rebrand the entire application.
/// All UI elements, paths, and identifiers should reference this config.
class Branding {
  Branding._();

  /// Primary brand color (deep purple)
  static const Color primaryColor = Colors.deepPurple;

  /// Path to app icon asset
  static const String appIconPath = 'assets/icons/app_icon.svg';

  /// The app's display name (shown in UI, window title, etc.)
  static const String appName = 'riot.ai';

  /// Short app name for file/directory names (no spaces, lowercase)
  static const String appId = 'riot';

  /// App description
  static const String appDescription =
      'Run multiple coding agents in parallel with git worktree isolation';

  /// Version string
  static const String version = '1.0.0';

  /// Organization/company name
  static const String organization = 'riot.ai';

  /// Directory name for storing app data in user's Documents folder
  /// e.g., ~/Documents/riot/sessions/
  static const String documentsFolder = 'riot';

  /// Directory name for git worktrees inside repos
  /// e.g., <repo>/.riot-worktrees/<session-id>/
  static const String worktreesFolder = '.riot-worktrees';

  /// Default branch prefix for agent branches
  static const String defaultBranchPrefix = 'riot';

  /// Window title format - use {name} for app name
  static String get windowTitle => appName;

  /// Full path helper for documents storage
  static String documentsPath(String homeDir) =>
      '$homeDir/Documents/$documentsFolder';

  /// Full path helper for sessions storage
  static String sessionsPath(String homeDir) =>
      '${documentsPath(homeDir)}/sessions';

  /// Full path helper for worktrees in a repo
  static String worktreesPath(String repoPath) => '$repoPath/$worktreesFolder';
}
