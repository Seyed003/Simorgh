// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Simorgh';

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

  @override
  String get tlsFragment => 'TLS fragment';

  @override
  String get tlsFragmentHint =>
      'Splits the start of each TLS connection so filtering cannot read the server name (SNI). Try Light first; Strong is slower';

  @override
  String get fragmentLight => 'Light';

  @override
  String get fragmentStrong => 'Strong';

  @override
  String get mux => 'Mux (multiplex)';

  @override
  String get muxHint =>
      'Sends many connections through a few; pages open faster. Your server must support it: if servers stop working, turn it off';

  @override
  String get muxProtocol => 'Mux protocol';

  @override
  String get speedTest => 'Speed test';

  @override
  String get speedTestGroup => 'Speed test these servers';

  @override
  String speedTestProgress(String current, String total) {
    return 'Speed test $current of $total';
  }

  @override
  String get speedTesting => 'Measuring speed…';

  @override
  String get speedFailed => 'Speed test failed';

  @override
  String get splitTunnel => 'Per-app proxy';

  @override
  String get splitTunnelOff => 'All apps';

  @override
  String get splitTunnelInclude => 'Only selected';

  @override
  String get splitTunnelExclude => 'All but selected';

  @override
  String get splitTunnelOffHint => 'Every app uses the VPN';

  @override
  String get splitTunnelIncludeHint =>
      'Only the apps you check use the VPN; the rest connect directly';

  @override
  String get splitTunnelExcludeHint =>
      'The apps you check connect directly, without the VPN';

  @override
  String get showSystemApps => 'Show system apps';

  @override
  String get clearSelection => 'Clear selection';

  @override
  String get searchApps => 'Search apps';

  @override
  String appsSelected(String count) {
    return '$count apps selected';
  }

  @override
  String get autoUpdateSubscriptions => 'Auto-update';

  @override
  String get autoUpdateSubscriptionsHint =>
      'Refreshes subscriptions when the app opens';

  @override
  String everyHours(String hours) {
    return 'Every $hours h';
  }

  @override
  String get dnsSystem => 'System DNS';

  @override
  String get dnsBlocksAds => 'blocks ads';

  @override
  String get dnsCustom => 'Custom…';

  @override
  String get usage => 'Usage';

  @override
  String get usageToday => 'Today';

  @override
  String get usageWeek => 'Last 7 days';

  @override
  String get usageMonth => 'Last 30 days';

  @override
  String get usageChartTitle => 'Last 14 days';

  @override
  String get usageTapHint => 'Tap a day for details';

  @override
  String get usageDaily => 'By day';

  @override
  String get usageEmpty =>
      'Nothing recorded yet. Usage is counted while you are connected.';

  @override
  String get usageReset => 'Reset statistics';

  @override
  String get usageResetConfirm => 'Delete all usage statistics?';

  @override
  String get cleanIpScan => 'Find a clean CDN IP';

  @override
  String get cleanIpHint =>
      'Finds CDN addresses (Cloudflare or ArvanCloud) your internet can reach. Configs that go through that CDN can use one instead of their blocked address.';

  @override
  String cleanIpTestingHost(String host) {
    return 'Tested with $host';
  }

  @override
  String get cleanIpDisconnectFirst =>
      'Disconnect first: the scan has to use your own internet, not the VPN.';

  @override
  String get cleanIpStart => 'Start scan';

  @override
  String cleanIpProgress(String tested, String total, String found) {
    return 'Tested $tested of $total · $found working';
  }

  @override
  String get cleanIpNone =>
      'No working address found. Try again later or on another network.';

  @override
  String get cleanIpUse => 'Make a copy of the config with this IP';

  @override
  String cleanIpCreated(String name) {
    return 'Added “$name”';
  }

  @override
  String get copyIp => 'Copy IP';

  @override
  String get blockQuic => 'Faster video and apps (block QUIC)';

  @override
  String get blockQuicHint =>
      'YouTube, Instagram and browsers use TCP instead of QUIC through the VPN, which is much faster on most servers';

  @override
  String get home => 'Home';

  @override
  String get tabUsage => 'Usage';

  @override
  String get advanced => 'Advanced';

  @override
  String get server => 'Server';

  @override
  String get tagline => 'Freedom to reach the whole internet';

  @override
  String get brandStory =>
      'The phoenix rises from its ashes: no filter can keep the internet from you for long.';

  @override
  String get proxyPassword => 'Require a password';

  @override
  String get proxyPasswordHint =>
      'Without it, any app on this device can use the proxy and find out your server';

  @override
  String proxyCredentials(String user, String password) {
    return 'User: $user · Password: $password';
  }

  @override
  String get killSwitch => 'Block internet without VPN';

  @override
  String get killSwitchOn => 'On: apps cannot go online while the VPN is off';

  @override
  String get killSwitchOff =>
      'Off: if the VPN stops, apps go online without it';

  @override
  String get killSwitchUnknown =>
      'Uses Android\'s Always-on VPN; tap to set up';

  @override
  String killSwitchSteps(String app) {
    return 'On the next screen, tap the gear next to \"$app\", then turn on \"Always-on VPN\" and \"Block connections without VPN\". Android only lets you change this there.';
  }

  @override
  String get openSettings => 'Open settings';

  @override
  String get insecure => 'Insecure';

  @override
  String get insecureHint =>
      'This config does not check who the server is (its certificate or SSH key): someone on the way could read or change its traffic';

  @override
  String get autoReconnecting => 'The connection dropped; reconnecting…';

  @override
  String get tools => 'Tools';

  @override
  String get backupSave => 'Save a backup';

  @override
  String get backupSaveHint =>
      'Configs, subscriptions and settings in one file. Keep it private: it holds your server passwords.';

  @override
  String get backupRestore => 'Restore from a backup';

  @override
  String get backupRestoreHint =>
      'Adds the backup\'s configs to yours and takes over its connection tuning. Per-app choices, the local proxy and custom DNS servers stay as they are on this device.';

  @override
  String get backupSaved => 'Backup saved';

  @override
  String backupRestored(String count) {
    return 'Restored: $count configs added';
  }

  @override
  String get backupInvalid => 'This file is not a backup of this app';

  @override
  String get logs => 'Logs';

  @override
  String get logsHint =>
      'What the core is doing; shows why a config does not connect';

  @override
  String get logsEmpty =>
      'No logs yet. They appear while connected; Advanced › Log level sets how detailed they are.';

  @override
  String get logsProblemsOnly => 'Warnings and errors only';

  @override
  String get copyAll => 'Copy all';

  @override
  String get importLinkTitle => 'Add from link';

  @override
  String importConfigsQuestion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count configs found. Add them?',
      one: '1 config found. Add it?',
    );
    return '$_temp0';
  }

  @override
  String importSubscriptionQuestion(String host) {
    return 'Add the subscription from $host?';
  }

  @override
  String updateAvailable(String version) {
    return 'Version $version is available';
  }

  @override
  String get updateHint => 'Install it over this one; your configs stay.';

  @override
  String get updateDownload => 'Download';

  @override
  String get updateLater => 'Later';

  @override
  String get updateCheck => 'Check for updates';

  @override
  String get updateLatest => 'You have the latest version';

  @override
  String get updateFailed => 'Could not check for updates';

  @override
  String get smartSetup => 'Smart setup for this internet';

  @override
  String get smartSetupHint =>
      'Tries the anti-filtering options with your servers and keeps what gets through best';

  @override
  String get networkWifi => 'Wi-Fi / home internet';

  @override
  String get networkMobile => 'Mobile data';

  @override
  String get networkEthernet => 'Wired internet';

  @override
  String get networkThisComputer => 'This computer';

  @override
  String get networkOther => 'This network';

  @override
  String get smartSetupStart => 'Start test';

  @override
  String smartSetupRunning(String count) {
    return 'Testing $count servers with each option…';
  }

  @override
  String smartSetupDone(String network, String mode) {
    return 'Best on $network: $mode. Applied.';
  }

  @override
  String get smartSetupNoServers =>
      'Add a config that uses TLS first (VLESS, VMess or Trojan); others do not need this.';

  @override
  String get smartSetupNothingWorks =>
      'No server answered on this network with any option. Try other servers or a clean IP.';

  @override
  String get smartSetupAuto => 'Switch automatically on each network';

  @override
  String get smartSetupAutoHint =>
      'When you connect, the setting that worked on that internet is used. Choosing a fragment mode by hand is remembered too.';

  @override
  String smartSetupRemembered(String mode) {
    return 'Remembered here: $mode';
  }

  @override
  String get smartSetupNotTested => 'Not tested on this network yet';

  @override
  String smartSetupScore(String ok, String total) {
    return '$ok of $total servers';
  }

  @override
  String get fragmentOff => 'No fragment';

  @override
  String get warpAdd => 'Free Cloudflare WARP';

  @override
  String get warpExplain =>
      'Creates a free Cloudflare WARP account on this device, adds it as a config and looks for an endpoint that works on your internet. WARP makes a good backup: it opens most sites, but it is not anonymous and is sometimes slow or blocked in Iran.';

  @override
  String warpAdded(String endpoint) {
    return 'WARP added (endpoint $endpoint)';
  }

  @override
  String get warpAddedNoEndpoint =>
      'WARP added, but no endpoint answered right now. Try \"Find a WARP endpoint\" from its menu later.';

  @override
  String warpFailed(String error) {
    return 'Could not reach Cloudflare ($error). Connect to a server first and try again.';
  }

  @override
  String get warpScan => 'Find a WARP endpoint';

  @override
  String warpScanDone(String endpoint) {
    return 'Endpoint changed to $endpoint';
  }

  @override
  String get warpScanNone => 'No WARP endpoint answered on this network';

  @override
  String get importFromFile => 'Import a file (.ovpn, JSON…)';

  @override
  String get ciscoAdd => 'Cisco AnyConnect';

  @override
  String get ciscoServer => 'Server address';

  @override
  String get ciscoGroup => 'Group (optional)';

  @override
  String get ciscoUnreachableTitle => 'Server not reachable';

  @override
  String ciscoUnreachable(String server) {
    return 'Could not reach $server to check its certificate. Add it anyway?';
  }

  @override
  String get ciscoUntrustedTitle => 'Unverified certificate';

  @override
  String ciscoUntrusted(String subject, String pin) {
    return 'No known authority vouches for this server\'s certificate, which is common for Cisco servers you buy. Trust it only if your provider gave you this server.\n\n$subject\n$pin';
  }

  @override
  String get ciscoTrust => 'Trust';

  @override
  String get loginTitle => 'Username and password';

  @override
  String get loginUsername => 'Username';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginUsernameRequired => 'Enter the username';

  @override
  String get loginNeeded => 'Needs username and password';

  @override
  String get errorLoginNeeded =>
      'Enter this server\'s username and password first';

  @override
  String get chainVia => 'Connect through another server';

  @override
  String get chainViaHint =>
      'For example a server in Iran that still reaches abroad';

  @override
  String get chainPickTitle => 'First server';

  @override
  String chainPickHint(String name) {
    return 'Traffic goes to this server first and from there to $name.';
  }

  @override
  String get chainNoOther => 'Add the other server first';

  @override
  String get chainCreated => 'Chained config added and selected';

  @override
  String chainThrough(String name) {
    return 'through $name';
  }

  @override
  String get cdnCloudflare => 'Cloudflare';

  @override
  String get cdnArvan => 'ArvanCloud';

  @override
  String get cdnArvanHint =>
      'For configs behind ArvanCloud\'s CDN. Its addresses are inside Iran, so they often keep working on the national internet.';

  @override
  String get shareApp => 'Share the app';

  @override
  String get shareAppHint =>
      'Send it to another phone by Bluetooth, Nearby Share or a messenger. No internet needed.';

  @override
  String get shareAppHintWindows =>
      'Opens the app’s folder: copy it to a flash drive for another PC.';

  @override
  String get shareAppTitle => 'Send Simorgh';

  @override
  String get shareAppFailed =>
      'This copy of the app can’t be sent as one file.';

  @override
  String get nationalTitle => 'Only Iranian sites are reachable';

  @override
  String get nationalHint =>
      'The international internet looks cut off (national internet). Configs with a server abroad won’t connect directly.';

  @override
  String get nationalHelp => 'What works?';

  @override
  String get nationalSheetTitle => 'On the national internet';

  @override
  String get nationalDns => 'DNS switched automatically';

  @override
  String get nationalDnsHint =>
      'Foreign DNS servers are cut off too, so server names are looked up with your network’s own DNS until this ends.';

  @override
  String get nationalRelay => 'Go through a server inside Iran';

  @override
  String get nationalRelayHint =>
      'Some servers in Iranian data centres keep their link abroad. If you have a config on one, open your foreign config’s menu → “Connect through another server” and pick it.';

  @override
  String get nationalCdn => 'ArvanCloud for CDN configs';

  @override
  String get nationalCdnHint =>
      'Configs behind ArvanCloud, an Iranian CDN, may keep working: config menu → “Find a clean CDN IP” → ArvanCloud.';

  @override
  String get nationalOffline => 'New configs and the app, offline';

  @override
  String get nationalOfflineHint =>
      'Get fresh configs through Iranian messengers, and pass this app on by Bluetooth with “Share the app”.';

  @override
  String get nationalTest => 'Test configs';

  @override
  String get nationalRecheck => 'Check again';

  @override
  String get nationalStillCut => 'Still only Iranian sites are reachable.';

  @override
  String get nationalBack => 'The international internet is reachable again.';

  @override
  String get subscriptionHttpWarning =>
      'This address is not encrypted (http, not https): your internet provider could read it and swap its configs for its own servers. Use an https link if the seller has one.';

  @override
  String get freeConfig => 'Free connection';

  @override
  String get freeServersName => 'Free servers';

  @override
  String get freeServersExplain =>
      "Uses free, public internet servers; the app finds the fastest working one and connects. These servers are not anonymous or trusted — don't use them for sensitive things like banking or signing in. If they're slow or down, try again in a moment.";

  @override
  String get freeServersFetching => 'Getting free servers…';

  @override
  String get freeServersReady => 'Free servers ready';

  @override
  String freeConfigTitle(String network) {
    return 'A free config for $network';
  }

  @override
  String get freeConfigExplain =>
      'Uses Cloudflare\'s free WARP. The app tries WARP\'s addresses on your internet, picks the fastest and remembers it for this operator; on another SIM or Wi-Fi it finds that network\'s best too. Takes up to a minute the first time.\n\nGood for blocked sites; it is not anonymous, and some operators slow or block WARP.';

  @override
  String get freeConfigStepNetwork => 'Checking your internet…';

  @override
  String get freeConfigStepAccount => 'Getting a free WARP account…';

  @override
  String get freeConfigStepChecking =>
      'Checking the route that worked here before…';

  @override
  String freeConfigStepScanning(String network) {
    return 'Finding the fastest route on $network…';
  }

  @override
  String freeConfigName(String network) {
    return 'Free · $network';
  }

  @override
  String freeConfigReady(String network) {
    return 'Free config ready for $network';
  }

  @override
  String freeConfigUnreachable(String network) {
    return 'WARP doesn\'t answer on $network right now: the operator may be blocking it. Try another network, or again later.';
  }

  @override
  String get freeConfigGo => 'Find and connect';
}
