/// Static facts about the application that never change at runtime.
abstract final class AppInfo {
  static const String name = 'Simorgh';
  static const String nameFa = 'سیمرغ';
  static const String repositoryUrl =
      'https://github.com/Seyed003/Simorgh';
  static const String license = 'GPL-3.0-or-later';

  /// Latest published release, read by the in-app update check.
  static const String latestReleaseApi =
      'https://api.github.com/repos/Seyed003/Simorgh/releases/latest';
  static const String releasesPage = '$repositoryUrl/releases/latest';

  /// Keep in sync with `version:` in pubspec.yaml.
  static const String version = '0.2.0';

  /// sing-box release that the Android libbox and the Windows binary are
  /// pinned to. Keep in sync with `scripts/core_version.txt`.
  static const String singBoxVersion = '1.14.3';
}
