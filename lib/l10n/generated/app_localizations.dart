import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fa'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Aghelan Ghiamat'**
  String get appTitle;

  /// No description provided for @statusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get statusDisconnected;

  /// No description provided for @statusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get statusConnecting;

  /// No description provided for @statusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get statusConnected;

  /// No description provided for @statusDisconnecting.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting…'**
  String get statusDisconnecting;

  /// No description provided for @statusError.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get statusError;

  /// No description provided for @tapToConnect.
  ///
  /// In en, this message translates to:
  /// **'Tap to connect'**
  String get tapToConnect;

  /// No description provided for @tapToDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Tap to disconnect'**
  String get tapToDisconnect;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @totalTraffic.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalTraffic;

  /// No description provided for @connectedFor.
  ///
  /// In en, this message translates to:
  /// **'Connected for {duration}'**
  String connectedFor(String duration);

  /// No description provided for @configs.
  ///
  /// In en, this message translates to:
  /// **'Configs'**
  String get configs;

  /// No description provided for @noConfigs.
  ///
  /// In en, this message translates to:
  /// **'No configs yet'**
  String get noConfigs;

  /// No description provided for @noConfigsHint.
  ///
  /// In en, this message translates to:
  /// **'Import a share link, a QR code or a subscription URL to get started.'**
  String get noConfigsHint;

  /// No description provided for @selectConfigFirst.
  ///
  /// In en, this message translates to:
  /// **'Select a config first'**
  String get selectConfigFirst;

  /// No description provided for @activeConfig.
  ///
  /// In en, this message translates to:
  /// **'Active config'**
  String get activeConfig;

  /// No description provided for @manualGroup.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manualGroup;

  /// No description provided for @addConfig.
  ///
  /// In en, this message translates to:
  /// **'Add config'**
  String get addConfig;

  /// No description provided for @importFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Import from clipboard'**
  String get importFromClipboard;

  /// No description provided for @scanQrCode.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get scanQrCode;

  /// No description provided for @importFromImage.
  ///
  /// In en, this message translates to:
  /// **'Import QR from image'**
  String get importFromImage;

  /// No description provided for @addSubscription.
  ///
  /// In en, this message translates to:
  /// **'Add subscription'**
  String get addSubscription;

  /// No description provided for @pasteManually.
  ///
  /// In en, this message translates to:
  /// **'Paste links manually'**
  String get pasteManually;

  /// No description provided for @pasteHint.
  ///
  /// In en, this message translates to:
  /// **'vless://…, vmess://…, trojan://…, ss://…, hy2://…'**
  String get pasteHint;

  /// No description provided for @subscriptionUrl.
  ///
  /// In en, this message translates to:
  /// **'Subscription URL'**
  String get subscriptionUrl;

  /// No description provided for @subscriptionName.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get subscriptionName;

  /// No description provided for @importedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No configs imported} =1{1 config imported} other{{count} configs imported}}'**
  String importedCount(int count);

  /// No description provided for @skippedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 line skipped} other{{count} lines skipped}}'**
  String skippedCount(int count);

  /// No description provided for @clipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Clipboard is empty'**
  String get clipboardEmpty;

  /// No description provided for @nothingToImport.
  ///
  /// In en, this message translates to:
  /// **'No supported config found'**
  String get nothingToImport;

  /// No description provided for @invalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid URL'**
  String get invalidUrl;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// No description provided for @qrNotFound.
  ///
  /// In en, this message translates to:
  /// **'No QR code found in the image'**
  String get qrNotFound;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera scanning is not available on this platform'**
  String get cameraUnavailable;

  /// No description provided for @subscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get subscriptions;

  /// No description provided for @updateSubscription.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateSubscription;

  /// No description provided for @updateAllSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Update all subscriptions'**
  String get updateAllSubscriptions;

  /// No description provided for @subscriptionUpdated.
  ///
  /// In en, this message translates to:
  /// **'{name} updated'**
  String subscriptionUpdated(String name);

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated: {time}'**
  String lastUpdated(String time);

  /// No description provided for @neverUpdated.
  ///
  /// In en, this message translates to:
  /// **'Never updated'**
  String get neverUpdated;

  /// No description provided for @trafficUsage.
  ///
  /// In en, this message translates to:
  /// **'{used} of {total}'**
  String trafficUsage(String used, String total);

  /// No description provided for @expiresOn.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String expiresOn(String date);

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @copyJson.
  ///
  /// In en, this message translates to:
  /// **'Copy sing-box JSON'**
  String get copyJson;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copied;

  /// No description provided for @showQrCode.
  ///
  /// In en, this message translates to:
  /// **'Show QR code'**
  String get showQrCode;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete?'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteConfigConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteConfigConfirm(String name);

  /// No description provided for @deleteSubscriptionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete subscription \"{name}\" and all of its configs?'**
  String deleteSubscriptionConfirm(String name);

  /// No description provided for @deleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all'**
  String get deleteAll;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languagePersian.
  ///
  /// In en, this message translates to:
  /// **'فارسی'**
  String get languagePersian;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @connectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connectionSettings;

  /// No description provided for @remoteDns.
  ///
  /// In en, this message translates to:
  /// **'Remote DNS'**
  String get remoteDns;

  /// No description provided for @directDns.
  ///
  /// In en, this message translates to:
  /// **'Direct DNS'**
  String get directDns;

  /// No description provided for @enableIpv6.
  ///
  /// In en, this message translates to:
  /// **'IPv6'**
  String get enableIpv6;

  /// No description provided for @enableIpv6Hint.
  ///
  /// In en, this message translates to:
  /// **'Route IPv6 traffic through the tunnel'**
  String get enableIpv6Hint;

  /// No description provided for @logLevel.
  ///
  /// In en, this message translates to:
  /// **'Core log level'**
  String get logLevel;

  /// No description provided for @mixedPort.
  ///
  /// In en, this message translates to:
  /// **'Local proxy port'**
  String get mixedPort;

  /// No description provided for @mixedPortHint.
  ///
  /// In en, this message translates to:
  /// **'HTTP + SOCKS5 proxy on 127.0.0.1'**
  String get mixedPortHint;

  /// No description provided for @tunStack.
  ///
  /// In en, this message translates to:
  /// **'TUN stack'**
  String get tunStack;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @coreVersion.
  ///
  /// In en, this message translates to:
  /// **'sing-box core'**
  String get coreVersion;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get sourceCode;

  /// No description provided for @errorVpnPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'VPN permission was denied'**
  String get errorVpnPermissionDenied;

  /// No description provided for @errorAdminRequired.
  ///
  /// In en, this message translates to:
  /// **'Run the app as administrator to use TUN mode'**
  String get errorAdminRequired;

  /// No description provided for @errorCoreMissing.
  ///
  /// In en, this message translates to:
  /// **'sing-box core was not found next to the app'**
  String get errorCoreMissing;

  /// No description provided for @errorCoreExited.
  ///
  /// In en, this message translates to:
  /// **'sing-box stopped unexpectedly: {message}'**
  String errorCoreExited(String message);

  /// No description provided for @errorUnsupportedPlatform.
  ///
  /// In en, this message translates to:
  /// **'This platform is not supported yet'**
  String get errorUnsupportedPlatform;

  /// No description provided for @trayShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get trayShow;

  /// No description provided for @trayQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get trayQuit;

  /// No description provided for @qrScanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at a QR code'**
  String get qrScanHint;

  /// No description provided for @cameraPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera permission was denied'**
  String get cameraPermissionDenied;

  /// No description provided for @updatingSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Updating subscriptions…'**
  String get updatingSubscriptions;

  /// No description provided for @subscriptionUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update: {names}'**
  String subscriptionUpdateFailed(String names);

  /// No description provided for @configCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 config} other{{count} configs}}'**
  String configCount(int count);

  /// No description provided for @unlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get unlimited;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @daysLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day left} other{{count} days left}}'**
  String daysLeft(int count);

  /// No description provided for @resetDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get resetDefaults;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @dnsAddressHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. https://1.1.1.1/dns-query, tls://8.8.8.8, 1.1.1.1, local'**
  String get dnsAddressHint;

  /// No description provided for @portHint.
  ///
  /// In en, this message translates to:
  /// **'1024–65535, empty to disable'**
  String get portHint;

  /// No description provided for @invalidValue.
  ///
  /// In en, this message translates to:
  /// **'Invalid value'**
  String get invalidValue;

  /// No description provided for @errorInvalidConfig.
  ///
  /// In en, this message translates to:
  /// **'This config cannot be started: {message}'**
  String errorInvalidConfig(String message);

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error: {message}'**
  String errorUnknown(String message);

  /// No description provided for @working.
  ///
  /// In en, this message translates to:
  /// **'Please wait…'**
  String get working;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @copyLinkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This config was imported from JSON and has no share link'**
  String get copyLinkUnavailable;

  /// No description provided for @noActiveConfig.
  ///
  /// In en, this message translates to:
  /// **'No config selected'**
  String get noActiveConfig;

  /// No description provided for @fingerprint.
  ///
  /// In en, this message translates to:
  /// **'TLS fingerprint (uTLS)'**
  String get fingerprint;

  /// No description provided for @fingerprintHint.
  ///
  /// In en, this message translates to:
  /// **'Applied to TLS configs that do not set one'**
  String get fingerprintHint;

  /// No description provided for @testAll.
  ///
  /// In en, this message translates to:
  /// **'Test all servers'**
  String get testAll;

  /// No description provided for @testServer.
  ///
  /// In en, this message translates to:
  /// **'Test latency'**
  String get testServer;

  /// No description provided for @testGroup.
  ///
  /// In en, this message translates to:
  /// **'Test these servers'**
  String get testGroup;

  /// No description provided for @stopTest.
  ///
  /// In en, this message translates to:
  /// **'Stop test'**
  String get stopTest;

  /// No description provided for @testProgress.
  ///
  /// In en, this message translates to:
  /// **'Testing {done}/{total}'**
  String testProgress(String done, String total);

  /// No description provided for @latencyMs.
  ///
  /// In en, this message translates to:
  /// **'{ms} ms'**
  String latencyMs(String ms);

  /// No description provided for @latencyTimeout.
  ///
  /// In en, this message translates to:
  /// **'Timeout'**
  String get latencyTimeout;

  /// No description provided for @latencyInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get latencyInvalid;

  /// No description provided for @latencyError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get latencyError;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortBy;

  /// No description provided for @sortDefault.
  ///
  /// In en, this message translates to:
  /// **'Default order'**
  String get sortDefault;

  /// No description provided for @sortLatency.
  ///
  /// In en, this message translates to:
  /// **'Fastest first'**
  String get sortLatency;

  /// No description provided for @autoSelect.
  ///
  /// In en, this message translates to:
  /// **'Auto (fastest server)'**
  String get autoSelect;

  /// No description provided for @autoSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Uses the fastest server and switches to another one if it stops working'**
  String get autoSelectHint;

  /// No description provided for @autoActive.
  ///
  /// In en, this message translates to:
  /// **'Auto: {name}'**
  String autoActive(String name);

  /// No description provided for @autoFinding.
  ///
  /// In en, this message translates to:
  /// **'Finding the fastest server…'**
  String get autoFinding;

  /// No description provided for @errorNoWorkingServer.
  ///
  /// In en, this message translates to:
  /// **'No working server found. Update your subscriptions or add new configs.'**
  String get errorNoWorkingServer;

  /// No description provided for @bypassIran.
  ///
  /// In en, this message translates to:
  /// **'Iranian sites without VPN'**
  String get bypassIran;

  /// No description provided for @bypassIranHint.
  ///
  /// In en, this message translates to:
  /// **'Iranian sites and apps (.ir and servers in Iran) connect directly: faster, saves your VPN traffic, and banking or government sites that block foreign IPs keep working'**
  String get bypassIranHint;

  /// No description provided for @tlsFragment.
  ///
  /// In en, this message translates to:
  /// **'TLS fragment'**
  String get tlsFragment;

  /// No description provided for @tlsFragmentHint.
  ///
  /// In en, this message translates to:
  /// **'Splits the start of each TLS connection so filtering cannot read the server name (SNI). Try Light first; Strong is slower'**
  String get tlsFragmentHint;

  /// No description provided for @fragmentLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get fragmentLight;

  /// No description provided for @fragmentStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get fragmentStrong;

  /// No description provided for @mux.
  ///
  /// In en, this message translates to:
  /// **'Mux (multiplex)'**
  String get mux;

  /// No description provided for @muxHint.
  ///
  /// In en, this message translates to:
  /// **'Sends many connections through a few; pages open faster. Your server must support it: if servers stop working, turn it off'**
  String get muxHint;

  /// No description provided for @muxProtocol.
  ///
  /// In en, this message translates to:
  /// **'Mux protocol'**
  String get muxProtocol;

  /// No description provided for @speedTest.
  ///
  /// In en, this message translates to:
  /// **'Speed test'**
  String get speedTest;

  /// No description provided for @speedTestGroup.
  ///
  /// In en, this message translates to:
  /// **'Speed test these servers'**
  String get speedTestGroup;

  /// No description provided for @speedTestProgress.
  ///
  /// In en, this message translates to:
  /// **'Speed test {current} of {total}'**
  String speedTestProgress(String current, String total);

  /// No description provided for @speedTesting.
  ///
  /// In en, this message translates to:
  /// **'Measuring speed…'**
  String get speedTesting;

  /// No description provided for @speedFailed.
  ///
  /// In en, this message translates to:
  /// **'Speed test failed'**
  String get speedFailed;

  /// No description provided for @splitTunnel.
  ///
  /// In en, this message translates to:
  /// **'Per-app proxy'**
  String get splitTunnel;

  /// No description provided for @splitTunnelOff.
  ///
  /// In en, this message translates to:
  /// **'All apps'**
  String get splitTunnelOff;

  /// No description provided for @splitTunnelInclude.
  ///
  /// In en, this message translates to:
  /// **'Only selected'**
  String get splitTunnelInclude;

  /// No description provided for @splitTunnelExclude.
  ///
  /// In en, this message translates to:
  /// **'All but selected'**
  String get splitTunnelExclude;

  /// No description provided for @splitTunnelOffHint.
  ///
  /// In en, this message translates to:
  /// **'Every app uses the VPN'**
  String get splitTunnelOffHint;

  /// No description provided for @splitTunnelIncludeHint.
  ///
  /// In en, this message translates to:
  /// **'Only the apps you check use the VPN; the rest connect directly'**
  String get splitTunnelIncludeHint;

  /// No description provided for @splitTunnelExcludeHint.
  ///
  /// In en, this message translates to:
  /// **'The apps you check connect directly, without the VPN'**
  String get splitTunnelExcludeHint;

  /// No description provided for @showSystemApps.
  ///
  /// In en, this message translates to:
  /// **'Show system apps'**
  String get showSystemApps;

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// No description provided for @searchApps.
  ///
  /// In en, this message translates to:
  /// **'Search apps'**
  String get searchApps;

  /// No description provided for @appsSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} apps selected'**
  String appsSelected(String count);

  /// No description provided for @autoUpdateSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Auto-update'**
  String get autoUpdateSubscriptions;

  /// No description provided for @autoUpdateSubscriptionsHint.
  ///
  /// In en, this message translates to:
  /// **'Refreshes subscriptions when the app opens'**
  String get autoUpdateSubscriptionsHint;

  /// No description provided for @everyHours.
  ///
  /// In en, this message translates to:
  /// **'Every {hours} h'**
  String everyHours(String hours);

  /// No description provided for @dnsSystem.
  ///
  /// In en, this message translates to:
  /// **'System DNS'**
  String get dnsSystem;

  /// No description provided for @dnsBlocksAds.
  ///
  /// In en, this message translates to:
  /// **'blocks ads'**
  String get dnsBlocksAds;

  /// No description provided for @dnsCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get dnsCustom;

  /// No description provided for @usage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get usage;

  /// No description provided for @usageToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get usageToday;

  /// No description provided for @usageWeek.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get usageWeek;

  /// No description provided for @usageMonth.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get usageMonth;

  /// No description provided for @usageChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Last 14 days'**
  String get usageChartTitle;

  /// No description provided for @usageTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a day for details'**
  String get usageTapHint;

  /// No description provided for @usageDaily.
  ///
  /// In en, this message translates to:
  /// **'By day'**
  String get usageDaily;

  /// No description provided for @usageEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet. Usage is counted while you are connected.'**
  String get usageEmpty;

  /// No description provided for @usageReset.
  ///
  /// In en, this message translates to:
  /// **'Reset statistics'**
  String get usageReset;

  /// No description provided for @usageResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete all usage statistics?'**
  String get usageResetConfirm;

  /// No description provided for @cleanIpScan.
  ///
  /// In en, this message translates to:
  /// **'Find a clean CDN IP'**
  String get cleanIpScan;

  /// No description provided for @cleanIpHint.
  ///
  /// In en, this message translates to:
  /// **'Finds CDN addresses (Cloudflare or ArvanCloud) your internet can reach. Configs that go through that CDN can use one instead of their blocked address.'**
  String get cleanIpHint;

  /// No description provided for @cleanIpTestingHost.
  ///
  /// In en, this message translates to:
  /// **'Tested with {host}'**
  String cleanIpTestingHost(String host);

  /// No description provided for @cleanIpDisconnectFirst.
  ///
  /// In en, this message translates to:
  /// **'Disconnect first: the scan has to use your own internet, not the VPN.'**
  String get cleanIpDisconnectFirst;

  /// No description provided for @cleanIpStart.
  ///
  /// In en, this message translates to:
  /// **'Start scan'**
  String get cleanIpStart;

  /// No description provided for @cleanIpProgress.
  ///
  /// In en, this message translates to:
  /// **'Tested {tested} of {total} · {found} working'**
  String cleanIpProgress(String tested, String total, String found);

  /// No description provided for @cleanIpNone.
  ///
  /// In en, this message translates to:
  /// **'No working address found. Try again later or on another network.'**
  String get cleanIpNone;

  /// No description provided for @cleanIpUse.
  ///
  /// In en, this message translates to:
  /// **'Make a copy of the config with this IP'**
  String get cleanIpUse;

  /// No description provided for @cleanIpCreated.
  ///
  /// In en, this message translates to:
  /// **'Added “{name}”'**
  String cleanIpCreated(String name);

  /// No description provided for @copyIp.
  ///
  /// In en, this message translates to:
  /// **'Copy IP'**
  String get copyIp;

  /// No description provided for @blockQuic.
  ///
  /// In en, this message translates to:
  /// **'Faster video and apps (block QUIC)'**
  String get blockQuic;

  /// No description provided for @blockQuicHint.
  ///
  /// In en, this message translates to:
  /// **'YouTube, Instagram and browsers use TCP instead of QUIC through the VPN, which is much faster on most servers'**
  String get blockQuicHint;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @tabUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get tabUsage;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Freedom to reach the whole internet'**
  String get tagline;

  /// No description provided for @brandStory.
  ///
  /// In en, this message translates to:
  /// **'The phoenix rises from its ashes: no filter can keep the internet from you for long.'**
  String get brandStory;

  /// No description provided for @proxyPassword.
  ///
  /// In en, this message translates to:
  /// **'Require a password'**
  String get proxyPassword;

  /// No description provided for @proxyPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Without it, any app on this device can use the proxy and find out your server'**
  String get proxyPasswordHint;

  /// No description provided for @proxyCredentials.
  ///
  /// In en, this message translates to:
  /// **'User: {user} · Password: {password}'**
  String proxyCredentials(String user, String password);

  /// No description provided for @killSwitch.
  ///
  /// In en, this message translates to:
  /// **'Block internet without VPN'**
  String get killSwitch;

  /// No description provided for @killSwitchOn.
  ///
  /// In en, this message translates to:
  /// **'On: apps cannot go online while the VPN is off'**
  String get killSwitchOn;

  /// No description provided for @killSwitchOff.
  ///
  /// In en, this message translates to:
  /// **'Off: if the VPN stops, apps go online without it'**
  String get killSwitchOff;

  /// No description provided for @killSwitchUnknown.
  ///
  /// In en, this message translates to:
  /// **'Uses Android\'s Always-on VPN; tap to set up'**
  String get killSwitchUnknown;

  /// No description provided for @killSwitchSteps.
  ///
  /// In en, this message translates to:
  /// **'On the next screen, tap the gear next to \"{app}\", then turn on \"Always-on VPN\" and \"Block connections without VPN\". Android only lets you change this there.'**
  String killSwitchSteps(String app);

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @insecure.
  ///
  /// In en, this message translates to:
  /// **'Insecure'**
  String get insecure;

  /// No description provided for @insecureHint.
  ///
  /// In en, this message translates to:
  /// **'This config does not check the server\'s certificate: someone on the way could read or change its traffic'**
  String get insecureHint;

  /// No description provided for @autoReconnecting.
  ///
  /// In en, this message translates to:
  /// **'The connection dropped; reconnecting…'**
  String get autoReconnecting;

  /// No description provided for @tools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// No description provided for @backupSave.
  ///
  /// In en, this message translates to:
  /// **'Save a backup'**
  String get backupSave;

  /// No description provided for @backupSaveHint.
  ///
  /// In en, this message translates to:
  /// **'Configs, subscriptions and settings in one file. Keep it private: it holds your server passwords.'**
  String get backupSaveHint;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup'**
  String get backupRestore;

  /// No description provided for @backupRestoreHint.
  ///
  /// In en, this message translates to:
  /// **'Adds the backup\'s configs to yours and takes over its settings'**
  String get backupRestoreHint;

  /// No description provided for @backupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get backupSaved;

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored: {count} configs added'**
  String backupRestored(String count);

  /// No description provided for @backupInvalid.
  ///
  /// In en, this message translates to:
  /// **'This file is not a backup of this app'**
  String get backupInvalid;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @logsHint.
  ///
  /// In en, this message translates to:
  /// **'What the core is doing; shows why a config does not connect'**
  String get logsHint;

  /// No description provided for @logsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No logs yet. They appear while connected; Advanced › Log level sets how detailed they are.'**
  String get logsEmpty;

  /// No description provided for @logsProblemsOnly.
  ///
  /// In en, this message translates to:
  /// **'Warnings and errors only'**
  String get logsProblemsOnly;

  /// No description provided for @copyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get copyAll;

  /// No description provided for @importLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Add from link'**
  String get importLinkTitle;

  /// No description provided for @importConfigsQuestion.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 config found. Add it?} other{{count} configs found. Add them?}}'**
  String importConfigsQuestion(int count);

  /// No description provided for @importSubscriptionQuestion.
  ///
  /// In en, this message translates to:
  /// **'Add the subscription from {host}?'**
  String importSubscriptionQuestion(String host);

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String updateAvailable(String version);

  /// No description provided for @updateHint.
  ///
  /// In en, this message translates to:
  /// **'Install it over this one; your configs stay.'**
  String get updateHint;

  /// No description provided for @updateDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get updateDownload;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateCheck.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get updateCheck;

  /// No description provided for @updateLatest.
  ///
  /// In en, this message translates to:
  /// **'You have the latest version'**
  String get updateLatest;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates'**
  String get updateFailed;

  /// No description provided for @smartSetup.
  ///
  /// In en, this message translates to:
  /// **'Smart setup for this internet'**
  String get smartSetup;

  /// No description provided for @smartSetupHint.
  ///
  /// In en, this message translates to:
  /// **'Tries the anti-filtering options with your servers and keeps what gets through best'**
  String get smartSetupHint;

  /// No description provided for @networkWifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi / home internet'**
  String get networkWifi;

  /// No description provided for @networkMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile data'**
  String get networkMobile;

  /// No description provided for @networkEthernet.
  ///
  /// In en, this message translates to:
  /// **'Wired internet'**
  String get networkEthernet;

  /// No description provided for @networkThisComputer.
  ///
  /// In en, this message translates to:
  /// **'This computer'**
  String get networkThisComputer;

  /// No description provided for @networkOther.
  ///
  /// In en, this message translates to:
  /// **'This network'**
  String get networkOther;

  /// No description provided for @smartSetupStart.
  ///
  /// In en, this message translates to:
  /// **'Start test'**
  String get smartSetupStart;

  /// No description provided for @smartSetupRunning.
  ///
  /// In en, this message translates to:
  /// **'Testing {count} servers with each option…'**
  String smartSetupRunning(String count);

  /// No description provided for @smartSetupDone.
  ///
  /// In en, this message translates to:
  /// **'Best on {network}: {mode}. Applied.'**
  String smartSetupDone(String network, String mode);

  /// No description provided for @smartSetupNoServers.
  ///
  /// In en, this message translates to:
  /// **'Add a config that uses TLS first (VLESS, VMess or Trojan); others do not need this.'**
  String get smartSetupNoServers;

  /// No description provided for @smartSetupNothingWorks.
  ///
  /// In en, this message translates to:
  /// **'No server answered on this network with any option. Try other servers or a clean IP.'**
  String get smartSetupNothingWorks;

  /// No description provided for @smartSetupAuto.
  ///
  /// In en, this message translates to:
  /// **'Switch automatically on each network'**
  String get smartSetupAuto;

  /// No description provided for @smartSetupAutoHint.
  ///
  /// In en, this message translates to:
  /// **'When you connect, the setting that worked on that internet is used. Choosing a fragment mode by hand is remembered too.'**
  String get smartSetupAutoHint;

  /// No description provided for @smartSetupRemembered.
  ///
  /// In en, this message translates to:
  /// **'Remembered here: {mode}'**
  String smartSetupRemembered(String mode);

  /// No description provided for @smartSetupNotTested.
  ///
  /// In en, this message translates to:
  /// **'Not tested on this network yet'**
  String get smartSetupNotTested;

  /// No description provided for @smartSetupScore.
  ///
  /// In en, this message translates to:
  /// **'{ok} of {total} servers'**
  String smartSetupScore(String ok, String total);

  /// No description provided for @fragmentOff.
  ///
  /// In en, this message translates to:
  /// **'No fragment'**
  String get fragmentOff;

  /// No description provided for @warpAdd.
  ///
  /// In en, this message translates to:
  /// **'Free Cloudflare WARP'**
  String get warpAdd;

  /// No description provided for @warpExplain.
  ///
  /// In en, this message translates to:
  /// **'Creates a free Cloudflare WARP account on this device, adds it as a config and looks for an endpoint that works on your internet. WARP makes a good backup: it opens most sites, but it is not anonymous and is sometimes slow or blocked in Iran.'**
  String get warpExplain;

  /// No description provided for @warpAdded.
  ///
  /// In en, this message translates to:
  /// **'WARP added (endpoint {endpoint})'**
  String warpAdded(String endpoint);

  /// No description provided for @warpAddedNoEndpoint.
  ///
  /// In en, this message translates to:
  /// **'WARP added, but no endpoint answered right now. Try \"Find a WARP endpoint\" from its menu later.'**
  String get warpAddedNoEndpoint;

  /// No description provided for @warpFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reach Cloudflare ({error}). Connect to a server first and try again.'**
  String warpFailed(String error);

  /// No description provided for @warpScan.
  ///
  /// In en, this message translates to:
  /// **'Find a WARP endpoint'**
  String get warpScan;

  /// No description provided for @warpScanDone.
  ///
  /// In en, this message translates to:
  /// **'Endpoint changed to {endpoint}'**
  String warpScanDone(String endpoint);

  /// No description provided for @warpScanNone.
  ///
  /// In en, this message translates to:
  /// **'No WARP endpoint answered on this network'**
  String get warpScanNone;

  /// No description provided for @importFromFile.
  ///
  /// In en, this message translates to:
  /// **'Import a file (.ovpn, JSON…)'**
  String get importFromFile;

  /// No description provided for @ciscoAdd.
  ///
  /// In en, this message translates to:
  /// **'Cisco AnyConnect'**
  String get ciscoAdd;

  /// No description provided for @ciscoServer.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get ciscoServer;

  /// No description provided for @ciscoGroup.
  ///
  /// In en, this message translates to:
  /// **'Group (optional)'**
  String get ciscoGroup;

  /// No description provided for @ciscoUnreachableTitle.
  ///
  /// In en, this message translates to:
  /// **'Server not reachable'**
  String get ciscoUnreachableTitle;

  /// No description provided for @ciscoUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach {server} to check its certificate. Add it anyway?'**
  String ciscoUnreachable(String server);

  /// No description provided for @ciscoUntrustedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unverified certificate'**
  String get ciscoUntrustedTitle;

  /// No description provided for @ciscoUntrusted.
  ///
  /// In en, this message translates to:
  /// **'No known authority vouches for this server\'s certificate, which is common for Cisco servers you buy. Trust it only if your provider gave you this server.\n\n{subject}\n{pin}'**
  String ciscoUntrusted(String subject, String pin);

  /// No description provided for @ciscoTrust.
  ///
  /// In en, this message translates to:
  /// **'Trust'**
  String get ciscoTrust;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Username and password'**
  String get loginTitle;

  /// No description provided for @loginUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get loginUsername;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// No description provided for @loginUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the username'**
  String get loginUsernameRequired;

  /// No description provided for @loginNeeded.
  ///
  /// In en, this message translates to:
  /// **'Needs username and password'**
  String get loginNeeded;

  /// No description provided for @errorLoginNeeded.
  ///
  /// In en, this message translates to:
  /// **'Enter this server\'s username and password first'**
  String get errorLoginNeeded;

  /// No description provided for @chainVia.
  ///
  /// In en, this message translates to:
  /// **'Connect through another server'**
  String get chainVia;

  /// No description provided for @chainViaHint.
  ///
  /// In en, this message translates to:
  /// **'For example a server in Iran that still reaches abroad'**
  String get chainViaHint;

  /// No description provided for @chainPickTitle.
  ///
  /// In en, this message translates to:
  /// **'First server'**
  String get chainPickTitle;

  /// No description provided for @chainPickHint.
  ///
  /// In en, this message translates to:
  /// **'Traffic goes to this server first and from there to {name}.'**
  String chainPickHint(String name);

  /// No description provided for @chainNoOther.
  ///
  /// In en, this message translates to:
  /// **'Add the other server first'**
  String get chainNoOther;

  /// No description provided for @chainCreated.
  ///
  /// In en, this message translates to:
  /// **'Chained config added and selected'**
  String get chainCreated;

  /// No description provided for @chainThrough.
  ///
  /// In en, this message translates to:
  /// **'through {name}'**
  String chainThrough(String name);

  /// No description provided for @cdnCloudflare.
  ///
  /// In en, this message translates to:
  /// **'Cloudflare'**
  String get cdnCloudflare;

  /// No description provided for @cdnArvan.
  ///
  /// In en, this message translates to:
  /// **'ArvanCloud'**
  String get cdnArvan;

  /// No description provided for @cdnArvanHint.
  ///
  /// In en, this message translates to:
  /// **'For configs behind ArvanCloud\'s CDN. Its addresses are inside Iran, so they often keep working on the national internet.'**
  String get cdnArvanHint;

  /// No description provided for @shareApp.
  ///
  /// In en, this message translates to:
  /// **'Share the app'**
  String get shareApp;

  /// No description provided for @shareAppHint.
  ///
  /// In en, this message translates to:
  /// **'Send it to another phone by Bluetooth, Nearby Share or a messenger. No internet needed.'**
  String get shareAppHint;

  /// No description provided for @shareAppHintWindows.
  ///
  /// In en, this message translates to:
  /// **'Opens the app’s folder: copy it to a flash drive for another PC.'**
  String get shareAppHintWindows;

  /// No description provided for @shareAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Send Aghelan Ghiamat'**
  String get shareAppTitle;

  /// No description provided for @shareAppFailed.
  ///
  /// In en, this message translates to:
  /// **'This copy of the app can’t be sent as one file.'**
  String get shareAppFailed;

  /// No description provided for @nationalTitle.
  ///
  /// In en, this message translates to:
  /// **'Only Iranian sites are reachable'**
  String get nationalTitle;

  /// No description provided for @nationalHint.
  ///
  /// In en, this message translates to:
  /// **'The international internet looks cut off (national internet). Configs with a server abroad won’t connect directly.'**
  String get nationalHint;

  /// No description provided for @nationalHelp.
  ///
  /// In en, this message translates to:
  /// **'What works?'**
  String get nationalHelp;

  /// No description provided for @nationalSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'On the national internet'**
  String get nationalSheetTitle;

  /// No description provided for @nationalDns.
  ///
  /// In en, this message translates to:
  /// **'DNS switched automatically'**
  String get nationalDns;

  /// No description provided for @nationalDnsHint.
  ///
  /// In en, this message translates to:
  /// **'Foreign DNS servers are cut off too, so server names are looked up with your network’s own DNS until this ends.'**
  String get nationalDnsHint;

  /// No description provided for @nationalRelay.
  ///
  /// In en, this message translates to:
  /// **'Go through a server inside Iran'**
  String get nationalRelay;

  /// No description provided for @nationalRelayHint.
  ///
  /// In en, this message translates to:
  /// **'Some servers in Iranian data centres keep their link abroad. If you have a config on one, open your foreign config’s menu → “Connect through another server” and pick it.'**
  String get nationalRelayHint;

  /// No description provided for @nationalCdn.
  ///
  /// In en, this message translates to:
  /// **'ArvanCloud for CDN configs'**
  String get nationalCdn;

  /// No description provided for @nationalCdnHint.
  ///
  /// In en, this message translates to:
  /// **'Configs behind ArvanCloud, an Iranian CDN, may keep working: config menu → “Find a clean CDN IP” → ArvanCloud.'**
  String get nationalCdnHint;

  /// No description provided for @nationalOffline.
  ///
  /// In en, this message translates to:
  /// **'New configs and the app, offline'**
  String get nationalOffline;

  /// No description provided for @nationalOfflineHint.
  ///
  /// In en, this message translates to:
  /// **'Get fresh configs through Iranian messengers, and pass this app on by Bluetooth with “Share the app”.'**
  String get nationalOfflineHint;

  /// No description provided for @nationalTest.
  ///
  /// In en, this message translates to:
  /// **'Test configs'**
  String get nationalTest;

  /// No description provided for @nationalRecheck.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get nationalRecheck;

  /// No description provided for @nationalStillCut.
  ///
  /// In en, this message translates to:
  /// **'Still only Iranian sites are reachable.'**
  String get nationalStillCut;

  /// No description provided for @nationalBack.
  ///
  /// In en, this message translates to:
  /// **'The international internet is reachable again.'**
  String get nationalBack;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fa':
      return AppLocalizationsFa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
