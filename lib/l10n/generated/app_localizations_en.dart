// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Aghelan Ghiamat';

  @override
  String get statusDisconnected => 'Disconnected';

  @override
  String get statusConnecting => 'Connecting…';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusDisconnecting => 'Disconnecting…';

  @override
  String get statusError => 'Connection failed';

  @override
  String get tapToConnect => 'Tap to connect';

  @override
  String get tapToDisconnect => 'Tap to disconnect';

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get upload => 'Upload';

  @override
  String get download => 'Download';

  @override
  String get totalTraffic => 'Total';

  @override
  String connectedFor(String duration) {
    return 'Connected for $duration';
  }

  @override
  String get configs => 'Configs';

  @override
  String get noConfigs => 'No configs yet';

  @override
  String get noConfigsHint =>
      'Import a share link, a QR code or a subscription URL to get started.';

  @override
  String get selectConfigFirst => 'Select a config first';

  @override
  String get activeConfig => 'Active config';

  @override
  String get manualGroup => 'Manual';

  @override
  String get addConfig => 'Add config';

  @override
  String get importFromClipboard => 'Import from clipboard';

  @override
  String get scanQrCode => 'Scan QR code';

  @override
  String get importFromImage => 'Import QR from image';

  @override
  String get addSubscription => 'Add subscription';

  @override
  String get pasteManually => 'Paste links manually';

  @override
  String get pasteHint => 'vless://…, vmess://…, trojan://…, ss://…, hy2://…';

  @override
  String get subscriptionUrl => 'Subscription URL';

  @override
  String get subscriptionName => 'Name (optional)';

  @override
  String importedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count configs imported',
      one: '1 config imported',
      zero: 'No configs imported',
    );
    return '$_temp0';
  }

  @override
  String skippedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines skipped',
      one: '1 line skipped',
    );
    return '$_temp0';
  }

  @override
  String get clipboardEmpty => 'Clipboard is empty';

  @override
  String get nothingToImport => 'No supported config found';

  @override
  String get invalidUrl => 'Invalid URL';

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get qrNotFound => 'No QR code found in the image';

  @override
  String get cameraUnavailable =>
      'Camera scanning is not available on this platform';

  @override
  String get subscriptions => 'Subscriptions';

  @override
  String get updateSubscription => 'Update';

  @override
  String get updateAllSubscriptions => 'Update all subscriptions';

  @override
  String subscriptionUpdated(String name) {
    return '$name updated';
  }

  @override
  String lastUpdated(String time) {
    return 'Last updated: $time';
  }

  @override
  String get neverUpdated => 'Never updated';

  @override
  String trafficUsage(String used, String total) {
    return '$used of $total';
  }

  @override
  String expiresOn(String date) {
    return 'Expires $date';
  }

  @override
  String get add => 'Add';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get rename => 'Rename';

  @override
  String get share => 'Share';

  @override
  String get copyLink => 'Copy link';

  @override
  String get copyJson => 'Copy sing-box JSON';

  @override
  String get copied => 'Copied to clipboard';

  @override
  String get showQrCode => 'Show QR code';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get deleteConfirmTitle => 'Delete?';

  @override
  String deleteConfigConfirm(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String deleteSubscriptionConfirm(String name) {
    return 'Delete subscription \"$name\" and all of its configs?';
  }

  @override
  String get deleteAll => 'Delete all';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get language => 'Language';

  @override
  String get languagePersian => 'فارسی';

  @override
  String get languageEnglish => 'English';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get connectionSettings => 'Connection';

  @override
  String get remoteDns => 'Remote DNS';

  @override
  String get directDns => 'Direct DNS';

  @override
  String get enableIpv6 => 'IPv6';

  @override
  String get enableIpv6Hint => 'Route IPv6 traffic through the tunnel';

  @override
  String get logLevel => 'Core log level';

  @override
  String get mixedPort => 'Local proxy port';

  @override
  String get mixedPortHint => 'HTTP + SOCKS5 proxy on 127.0.0.1';

  @override
  String get tunStack => 'TUN stack';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get coreVersion => 'sing-box core';

  @override
  String get license => 'License';

  @override
  String get sourceCode => 'Source code';

  @override
  String get errorVpnPermissionDenied => 'VPN permission was denied';

  @override
  String get errorAdminRequired =>
      'Run the app as administrator to use TUN mode';

  @override
  String get errorCoreMissing => 'sing-box core was not found next to the app';

  @override
  String errorCoreExited(String message) {
    return 'sing-box stopped unexpectedly: $message';
  }

  @override
  String get errorUnsupportedPlatform => 'This platform is not supported yet';

  @override
  String get trayShow => 'Show';

  @override
  String get trayQuit => 'Quit';

  @override
  String get qrScanHint => 'Point the camera at a QR code';

  @override
  String get cameraPermissionDenied => 'Camera permission was denied';

  @override
  String get updatingSubscriptions => 'Updating subscriptions…';

  @override
  String subscriptionUpdateFailed(String names) {
    return 'Could not update: $names';
  }

  @override
  String configCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count configs',
      one: '1 config',
    );
    return '$_temp0';
  }

  @override
  String get unlimited => 'Unlimited';

  @override
  String get expired => 'Expired';

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String get resetDefaults => 'Reset to defaults';

  @override
  String get disabled => 'Disabled';

  @override
  String get dnsAddressHint =>
      'e.g. https://1.1.1.1/dns-query, tls://8.8.8.8, 1.1.1.1, local';

  @override
  String get portHint => '1024–65535, empty to disable';

  @override
  String get invalidValue => 'Invalid value';

  @override
  String errorInvalidConfig(String message) {
    return 'This config cannot be started: $message';
  }

  @override
  String errorUnknown(String message) {
    return 'Unexpected error: $message';
  }

  @override
  String get working => 'Please wait…';

  @override
  String get name => 'Name';

  @override
  String get copyLinkUnavailable =>
      'This config was imported from JSON and has no share link';

  @override
  String get noActiveConfig => 'No config selected';

  @override
  String get fingerprint => 'TLS fingerprint (uTLS)';

  @override
  String get fingerprintHint => 'Applied to TLS configs that do not set one';

  @override
  String get testAll => 'Test all servers';

  @override
  String get testServer => 'Test latency';

  @override
  String get testGroup => 'Test these servers';

  @override
  String get stopTest => 'Stop test';

  @override
  String testProgress(String done, String total) {
    return 'Testing $done/$total';
  }

  @override
  String latencyMs(String ms) {
    return '$ms ms';
  }

  @override
  String get latencyTimeout => 'Timeout';

  @override
  String get latencyInvalid => 'Invalid';

  @override
  String get latencyError => 'Error';

  @override
  String get sortBy => 'Sort';

  @override
  String get sortDefault => 'Default order';

  @override
  String get sortLatency => 'Fastest first';

  @override
  String get autoSelect => 'Auto (fastest server)';

  @override
  String get autoSelectHint =>
      'Uses the fastest server and switches to another one if it stops working';

  @override
  String autoActive(String name) {
    return 'Auto: $name';
  }

  @override
  String get autoFinding => 'Finding the fastest server…';

  @override
  String get errorNoWorkingServer =>
      'No working server found. Update your subscriptions or add new configs.';

  @override
  String get bypassIran => 'Iranian sites without VPN';

  @override
  String get bypassIranHint =>
      'Iranian sites and apps (.ir and servers in Iran) connect directly: faster, saves your VPN traffic, and banking or government sites that block foreign IPs keep working';
}
