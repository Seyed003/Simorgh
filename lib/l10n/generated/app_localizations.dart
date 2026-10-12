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
