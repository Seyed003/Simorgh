/// Static facts about the application that never change at runtime.
abstract final class AppInfo {
  static const String name = 'Aghelan Ghiamat';
  static const String nameFa = 'عاقلان قیامت';
  static const String repositoryUrl =
      'https://github.com/seyed003/aghelan-ghiamat';
  static const String license = 'GPL-3.0-or-later';

  /// sing-box release that the Android libbox and the Windows binary are
  /// pinned to. Keep in sync with `scripts/core_version.txt`.
  static const String singBoxVersion = '1.14.3';
}
