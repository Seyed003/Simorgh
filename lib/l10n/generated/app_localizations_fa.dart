// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get appTitle => 'عاقلان قیامت';

  @override
  String get statusDisconnected => 'قطع';

  @override
  String get statusConnecting => 'در حال اتصال…';

  @override
  String get statusConnected => 'متصل';

  @override
  String get statusDisconnecting => 'در حال قطع اتصال…';

  @override
  String get statusError => 'اتصال ناموفق بود';

  @override
  String get tapToConnect => 'برای اتصال لمس کنید';

  @override
  String get tapToDisconnect => 'برای قطع اتصال لمس کنید';

  @override
  String get connect => 'اتصال';

  @override
  String get disconnect => 'قطع اتصال';

  @override
  String get upload => 'آپلود';

  @override
  String get download => 'دانلود';

  @override
  String get totalTraffic => 'مجموع';

  @override
  String connectedFor(String duration) {
    return 'مدت اتصال: $duration';
  }

  @override
  String get configs => 'کانفیگ‌ها';

  @override
  String get noConfigs => 'هنوز کانفیگی ندارید';

  @override
  String get noConfigsHint =>
      'برای شروع، یک لینک اشتراک، کد QR یا لینک سابسکریپشن وارد کنید.';

  @override
  String get selectConfigFirst => 'ابتدا یک کانفیگ انتخاب کنید';

  @override
  String get activeConfig => 'کانفیگ فعال';

  @override
  String get manualGroup => 'دستی';

  @override
  String get addConfig => 'افزودن کانفیگ';

  @override
  String get importFromClipboard => 'وارد کردن از کلیپ‌بورد';

  @override
  String get scanQrCode => 'اسکن کد QR';

  @override
  String get importFromImage => 'وارد کردن QR از تصویر';

  @override
  String get addSubscription => 'افزودن سابسکریپشن';

  @override
  String get pasteManually => 'چسباندن دستی لینک‌ها';

  @override
  String get pasteHint => 'vless://…، vmess://…، trojan://…، ss://…، hy2://…';

  @override
  String get subscriptionUrl => 'آدرس سابسکریپشن';

  @override
  String get subscriptionName => 'نام (اختیاری)';

  @override
  String importedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کانفیگ وارد شد',
      zero: 'هیچ کانفیگی وارد نشد',
    );
    return '$_temp0';
  }

  @override
  String skippedCount(int count) {
    return '$count خط نادیده گرفته شد';
  }

  @override
  String get clipboardEmpty => 'کلیپ‌بورد خالی است';

  @override
  String get nothingToImport => 'هیچ کانفیگ پشتیبانی‌شده‌ای پیدا نشد';

  @override
  String get invalidUrl => 'آدرس نامعتبر است';

  @override
  String importFailed(String error) {
    return 'وارد کردن ناموفق بود: $error';
  }

  @override
  String get qrNotFound => 'کد QR در تصویر پیدا نشد';

  @override
  String get cameraUnavailable => 'اسکن با دوربین روی این پلتفرم در دسترس نیست';

  @override
  String get subscriptions => 'سابسکریپشن‌ها';

  @override
  String get updateSubscription => 'به‌روزرسانی';

  @override
  String get updateAllSubscriptions => 'به‌روزرسانی همه سابسکریپشن‌ها';

  @override
  String subscriptionUpdated(String name) {
    return '$name به‌روز شد';
  }

  @override
  String lastUpdated(String time) {
    return 'آخرین به‌روزرسانی: $time';
  }

  @override
  String get neverUpdated => 'هنوز به‌روز نشده';

  @override
  String trafficUsage(String used, String total) {
    return '$used از $total';
  }

  @override
  String expiresOn(String date) {
    return 'انقضا: $date';
  }

  @override
  String get add => 'افزودن';

  @override
  String get cancel => 'انصراف';

  @override
  String get save => 'ذخیره';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'ویرایش';

  @override
  String get rename => 'تغییر نام';

  @override
  String get share => 'اشتراک‌گذاری';

  @override
  String get copyLink => 'کپی لینک';

  @override
  String get copyJson => 'کپی JSON سینگ‌باکس';

  @override
  String get copied => 'در کلیپ‌بورد کپی شد';

  @override
  String get showQrCode => 'نمایش کد QR';

  @override
  String get close => 'بستن';

  @override
  String get retry => 'تلاش دوباره';

  @override
  String get deleteConfirmTitle => 'حذف شود؟';

  @override
  String deleteConfigConfirm(String name) {
    return '«$name» حذف شود؟';
  }

  @override
  String deleteSubscriptionConfirm(String name) {
    return 'سابسکریپشن «$name» و همه کانفیگ‌هایش حذف شوند؟';
  }

  @override
  String get deleteAll => 'حذف همه';

  @override
  String get settings => 'تنظیمات';

  @override
  String get appearance => 'ظاهر';

  @override
  String get language => 'زبان';

  @override
  String get languagePersian => 'فارسی';

  @override
  String get languageEnglish => 'English';

  @override
  String get theme => 'پوسته';

  @override
  String get themeSystem => 'پیش‌فرض سیستم';

  @override
  String get themeLight => 'روشن';

  @override
  String get themeDark => 'تیره';

  @override
  String get connectionSettings => 'اتصال';

  @override
  String get remoteDns => 'DNS راه دور';

  @override
  String get directDns => 'DNS مستقیم';

  @override
  String get enableIpv6 => 'IPv6';

  @override
  String get enableIpv6Hint => 'عبور ترافیک IPv6 از تونل';

  @override
  String get logLevel => 'سطح لاگ هسته';

  @override
  String get mixedPort => 'پورت پراکسی محلی';

  @override
  String get mixedPortHint => 'پراکسی HTTP و SOCKS5 روی 127.0.0.1';

  @override
  String get tunStack => 'استک TUN';

  @override
  String get about => 'درباره';

  @override
  String get version => 'نسخه';

  @override
  String get coreVersion => 'هسته sing-box';

  @override
  String get license => 'مجوز';

  @override
  String get sourceCode => 'کد منبع';

  @override
  String get errorVpnPermissionDenied => 'مجوز VPN داده نشد';

  @override
  String get errorAdminRequired =>
      'برای حالت TUN برنامه را با دسترسی Administrator اجرا کنید';

  @override
  String get errorCoreMissing => 'هسته sing-box کنار برنامه پیدا نشد';

  @override
  String errorCoreExited(String message) {
    return 'sing-box به‌طور غیرمنتظره متوقف شد: $message';
  }

  @override
  String get errorUnsupportedPlatform => 'این پلتفرم هنوز پشتیبانی نمی‌شود';

  @override
  String get trayShow => 'نمایش';

  @override
  String get trayQuit => 'خروج';

  @override
  String get qrScanHint => 'دوربین را به سمت کد QR بگیرید';

  @override
  String get cameraPermissionDenied => 'مجوز دوربین داده نشد';

  @override
  String get updatingSubscriptions => 'در حال به‌روزرسانی سابسکریپشن‌ها…';

  @override
  String subscriptionUpdateFailed(String names) {
    return 'به‌روزرسانی ناموفق: $names';
  }

  @override
  String configCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کانفیگ',
    );
    return '$_temp0';
  }

  @override
  String get unlimited => 'نامحدود';

  @override
  String get expired => 'منقضی شده';

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count روز باقی‌مانده',
    );
    return '$_temp0';
  }

  @override
  String get resetDefaults => 'بازگشت به پیش‌فرض';

  @override
  String get disabled => 'غیرفعال';

  @override
  String get dnsAddressHint =>
      'مثلاً https://1.1.1.1/dns-query یا tls://8.8.8.8 یا 1.1.1.1 یا local';

  @override
  String get portHint => '۱۰۲۴ تا ۶۵۵۳۵، خالی برای غیرفعال‌سازی';

  @override
  String get invalidValue => 'مقدار نامعتبر است';

  @override
  String errorInvalidConfig(String message) {
    return 'این کانفیگ قابل اجرا نیست: $message';
  }

  @override
  String errorUnknown(String message) {
    return 'خطای غیرمنتظره: $message';
  }

  @override
  String get working => 'لطفاً صبر کنید…';

  @override
  String get name => 'نام';

  @override
  String get copyLinkUnavailable =>
      'این کانفیگ از JSON وارد شده و لینک اشتراک ندارد';

  @override
  String get noActiveConfig => 'کانفیگی انتخاب نشده';

  @override
  String get fingerprint => 'اثرانگشت TLS (uTLS)';

  @override
  String get fingerprintHint =>
      'روی کانفیگ‌های TLS که اثرانگشت ندارند اعمال می‌شود';

  @override
  String get testAll => 'تست همه‌ی سرورها';

  @override
  String get testServer => 'تست پینگ';

  @override
  String get testGroup => 'تست این سرورها';

  @override
  String get stopTest => 'توقف تست';

  @override
  String testProgress(String done, String total) {
    return 'در حال تست $done از $total';
  }

  @override
  String latencyMs(String ms) {
    return '$ms ms';
  }

  @override
  String get latencyTimeout => 'پاسخ نداد';

  @override
  String get latencyInvalid => 'نامعتبر';

  @override
  String get latencyError => 'خطا';

  @override
  String get sortBy => 'مرتب‌سازی';

  @override
  String get sortDefault => 'ترتیب پیش‌فرض';

  @override
  String get sortLatency => 'سریع‌ترین اول';

  @override
  String get autoSelect => 'خودکار (سریع‌ترین سرور)';

  @override
  String get autoSelectHint =>
      'به سریع‌ترین سرور وصل می‌شود و اگر قطع شد، خودش سرور دیگری را جایگزین می‌کند';

  @override
  String autoActive(String name) {
    return 'خودکار: $name';
  }

  @override
  String get autoFinding => 'در حال پیدا کردن سریع‌ترین سرور…';

  @override
  String get errorNoWorkingServer =>
      'هیچ سرور سالمی پیدا نشد. سابسکریپشن‌ها را به‌روز کنید یا کانفیگ جدید اضافه کنید.';

  @override
  String get bypassIran => 'سایت‌های ایرانی بدون VPN';

  @override
  String get bypassIranHint =>
      'سایت‌ها و برنامه‌های ایرانی (دامنه‌های ‎.ir و سرورهای داخل ایران) مستقیم باز می‌شوند: سریع‌تر است، حجم VPN مصرف نمی‌شود و سایت‌های بانکی و دولتی که IP خارجی را مسدود می‌کنند کار می‌کنند';

  @override
  String get tlsFragment => 'فرگمنت TLS';

  @override
  String get tlsFragmentHint =>
      'شروع هر اتصال TLS را تکه‌تکه می‌کند تا فیلترینگ نتواند نام سرور (SNI) را بخواند. اول «سبک» را امتحان کنید؛ «قوی» کندتر است';

  @override
  String get fragmentLight => 'سبک';

  @override
  String get fragmentStrong => 'قوی';

  @override
  String get mux => 'Mux (چندگانه‌سازی)';

  @override
  String get muxHint =>
      'چند اتصال را از چند مسیر محدود می‌فرستد و صفحه‌ها سریع‌تر باز می‌شوند. سرور باید از آن پشتیبانی کند؛ اگر سرورها کار نکردند، خاموشش کنید';

  @override
  String get muxProtocol => 'پروتکل Mux';

  @override
  String get speedTest => 'تست سرعت';

  @override
  String get speedTestGroup => 'تست سرعت این سرورها';

  @override
  String speedTestProgress(String current, String total) {
    return 'تست سرعت $current از $total';
  }

  @override
  String get speedTesting => 'در حال اندازه‌گیری سرعت…';

  @override
  String get speedFailed => 'تست سرعت ناموفق';

  @override
  String get splitTunnel => 'انتخاب برنامه‌ها (Split Tunnel)';

  @override
  String get splitTunnelOff => 'همه‌ی برنامه‌ها';

  @override
  String get splitTunnelInclude => 'فقط انتخاب‌شده‌ها';

  @override
  String get splitTunnelExclude => 'همه به‌جز انتخاب‌شده‌ها';

  @override
  String get splitTunnelOffHint => 'همه‌ی برنامه‌ها از VPN استفاده می‌کنند';

  @override
  String get splitTunnelIncludeHint =>
      'فقط برنامه‌هایی که تیک بزنید از VPN استفاده می‌کنند؛ بقیه مستقیم وصل می‌شوند';

  @override
  String get splitTunnelExcludeHint =>
      'برنامه‌هایی که تیک بزنید بدون VPN و مستقیم وصل می‌شوند';

  @override
  String get showSystemApps => 'نمایش برنامه‌های سیستمی';

  @override
  String get clearSelection => 'پاک کردن انتخاب‌ها';

  @override
  String get searchApps => 'جستجوی برنامه';

  @override
  String appsSelected(String count) {
    return '$count برنامه انتخاب شده';
  }

  @override
  String get autoUpdateSubscriptions => 'به‌روزرسانی خودکار';

  @override
  String get autoUpdateSubscriptionsHint =>
      'سابسکریپشن‌ها هنگام باز شدن برنامه به‌روز می‌شوند';

  @override
  String everyHours(String hours) {
    return 'هر $hours ساعت';
  }

  @override
  String get dnsSystem => 'DNS سیستم';

  @override
  String get dnsBlocksAds => 'حذف تبلیغات';

  @override
  String get dnsCustom => 'دلخواه…';

  @override
  String get usage => 'مصرف اینترنت';

  @override
  String get usageToday => 'امروز';

  @override
  String get usageWeek => '۷ روز اخیر';

  @override
  String get usageMonth => '۳۰ روز اخیر';

  @override
  String get usageChartTitle => '۱۴ روز اخیر';

  @override
  String get usageTapHint => 'برای جزئیات روی هر روز بزنید';

  @override
  String get usageDaily => 'مصرف روزانه';

  @override
  String get usageEmpty =>
      'هنوز مصرفی ثبت نشده. مصرف در زمان اتصال شمرده می‌شود.';

  @override
  String get usageReset => 'پاک کردن آمار';

  @override
  String get usageResetConfirm => 'همه‌ی آمار مصرف پاک شود؟';

  @override
  String get cleanIpScan => 'پیدا کردن IP تمیز CDN';

  @override
  String get cleanIpHint =>
      'IPهای CDN (کلودفلر یا ابرآروان) را پیدا می‌کند که اینترنت شما به آن‌ها دسترسی دارد. کانفیگ‌هایی که از همان CDN رد می‌شوند می‌توانند به‌جای آدرس مسدودشده از آن استفاده کنند.';

  @override
  String cleanIpTestingHost(String host) {
    return 'تست با دامنه‌ی $host';
  }

  @override
  String get cleanIpDisconnectFirst =>
      'اول VPN را قطع کنید؛ اسکن باید با اینترنت خودتان انجام شود، نه از داخل VPN.';

  @override
  String get cleanIpStart => 'شروع اسکن';

  @override
  String cleanIpProgress(String tested, String total, String found) {
    return '$tested از $total تست شد · $found سالم';
  }

  @override
  String get cleanIpNone =>
      'IP سالمی پیدا نشد. بعداً یا روی اینترنت دیگری دوباره امتحان کنید.';

  @override
  String get cleanIpUse => 'ساخت کپی کانفیگ با این IP';

  @override
  String cleanIpCreated(String name) {
    return '«$name» اضافه شد';
  }

  @override
  String get copyIp => 'کپی IP';

  @override
  String get blockQuic => 'سرعت بیشتر ویدیو و برنامه‌ها (مسدود کردن QUIC)';

  @override
  String get blockQuicHint =>
      'یوتیوب، اینستاگرام و مرورگرها به‌جای QUIC از TCP استفاده می‌کنند که از داخل VPN روی بیشتر سرورها خیلی سریع‌تر است';

  @override
  String get home => 'خانه';

  @override
  String get tabUsage => 'مصرف';

  @override
  String get advanced => 'پیشرفته';

  @override
  String get server => 'سرور';

  @override
  String get tagline => 'آزادی دسترسی به دنیای اینترنت';

  @override
  String get brandStory =>
      'ققنوس از خاکستر خود برمی‌خیزد؛ هیچ فیلتری نمی‌تواند اینترنت را برای همیشه از شما دور نگه دارد.';

  @override
  String get proxyPassword => 'درخواست رمز عبور';

  @override
  String get proxyPasswordHint =>
      'بدون رمز، هر برنامه‌ای روی این دستگاه می‌تواند از پراکسی استفاده کند و آدرس سرور شما را بفهمد';

  @override
  String proxyCredentials(String user, String password) {
    return 'نام کاربری: $user · رمز: $password';
  }

  @override
  String get killSwitch => 'قطع اینترنت بدون VPN';

  @override
  String get killSwitchOn =>
      'روشن: وقتی VPN قطع است، برنامه‌ها به اینترنت وصل نمی‌شوند';

  @override
  String get killSwitchOff =>
      'خاموش: اگر VPN قطع شود، برنامه‌ها بدون آن به اینترنت وصل می‌شوند';

  @override
  String get killSwitchUnknown =>
      'با «VPN همیشه روشن» اندروید کار می‌کند؛ برای تنظیم لمس کنید';

  @override
  String killSwitchSteps(String app) {
    return 'در صفحه بعد، چرخ‌دنده کنار «$app» را بزنید و «VPN همیشه روشن» و «مسدود کردن اتصال‌های بدون VPN» را روشن کنید. اندروید فقط از همان‌جا اجازه این تنظیم را می‌دهد.';
  }

  @override
  String get openSettings => 'باز کردن تنظیمات';

  @override
  String get insecure => 'ناامن';

  @override
  String get insecureHint =>
      'این کانفیگ هویت سرور (گواهی یا کلید SSH) را بررسی نمی‌کند؛ کسی که سر راه است می‌تواند ترافیک را بخواند یا تغییر دهد';

  @override
  String get autoReconnecting => 'اتصال قطع شد؛ در حال وصل شدن دوباره…';

  @override
  String get tools => 'ابزارها';

  @override
  String get backupSave => 'ذخیره نسخه پشتیبان';

  @override
  String get backupSaveHint =>
      'کانفیگ‌ها، سابسکریپشن‌ها و تنظیمات در یک فایل. آن را جای امنی نگه دارید؛ رمز سرورهای شما داخل آن است.';

  @override
  String get backupRestore => 'بازگردانی از نسخه پشتیبان';

  @override
  String get backupRestoreHint =>
      'کانفیگ‌های پشتیبان به کانفیگ‌های شما اضافه و تنظیمات اتصالش اعمال می‌شود. انتخاب برنامه‌ها، پروکسی محلی و DNSهای دلخواه همان‌طور که روی این دستگاه هستند می‌مانند.';

  @override
  String get backupSaved => 'نسخه پشتیبان ذخیره شد';

  @override
  String backupRestored(String count) {
    return 'بازگردانی شد: $count کانفیگ اضافه شد';
  }

  @override
  String get backupInvalid => 'این فایل، نسخه پشتیبان این برنامه نیست';

  @override
  String get logs => 'گزارش‌ها (لاگ)';

  @override
  String get logsHint => 'کارهای هسته؛ نشان می‌دهد چرا یک کانفیگ وصل نمی‌شود';

  @override
  String get logsEmpty =>
      'هنوز لاگی نیست. لاگ‌ها هنگام اتصال نمایش داده می‌شوند؛ میزان جزئیات در «پیشرفته › سطح لاگ» است.';

  @override
  String get logsProblemsOnly => 'فقط هشدارها و خطاها';

  @override
  String get copyAll => 'کپی همه';

  @override
  String get importLinkTitle => 'افزودن از لینک';

  @override
  String importConfigsQuestion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کانفیگ پیدا شد. اضافه شوند؟',
      one: '۱ کانفیگ پیدا شد. اضافه شود؟',
    );
    return '$_temp0';
  }

  @override
  String importSubscriptionQuestion(String host) {
    return 'سابسکریپشن $host اضافه شود؟';
  }

  @override
  String updateAvailable(String version) {
    return 'نسخه $version آماده است';
  }

  @override
  String get updateHint =>
      'روی همین نسخه نصب کنید؛ کانفیگ‌ها سر جایشان می‌مانند.';

  @override
  String get updateDownload => 'دانلود';

  @override
  String get updateLater => 'بعداً';

  @override
  String get updateCheck => 'بررسی نسخه جدید';

  @override
  String get updateLatest => 'آخرین نسخه را دارید';

  @override
  String get updateFailed => 'بررسی نسخه جدید ممکن نشد';

  @override
  String get smartSetup => 'تنظیم هوشمند برای این اینترنت';

  @override
  String get smartSetupHint =>
      'گزینه‌های ضدفیلتر را با سرورهای شما امتحان می‌کند و آن را که بهتر عبور می‌کند نگه می‌دارد';

  @override
  String get networkWifi => 'وای‌فای / اینترنت خانگی';

  @override
  String get networkMobile => 'اینترنت همراه';

  @override
  String get networkEthernet => 'اینترنت کابلی';

  @override
  String get networkThisComputer => 'این کامپیوتر';

  @override
  String get networkOther => 'این شبکه';

  @override
  String get smartSetupStart => 'شروع آزمایش';

  @override
  String smartSetupRunning(String count) {
    return 'در حال آزمایش $count سرور با هر گزینه…';
  }

  @override
  String smartSetupDone(String network, String mode) {
    return 'بهترین گزینه روی $network: $mode. اعمال شد.';
  }

  @override
  String get smartSetupNoServers =>
      'ابتدا یک کانفیگ دارای TLS اضافه کنید (VLESS، VMess یا Trojan)؛ بقیه به این تنظیم نیاز ندارند.';

  @override
  String get smartSetupNothingWorks =>
      'روی این شبکه هیچ سروری با هیچ گزینه‌ای جواب نداد. سرورهای دیگر یا IP تمیز را امتحان کنید.';

  @override
  String get smartSetupAuto => 'تغییر خودکار روی هر شبکه';

  @override
  String get smartSetupAutoHint =>
      'هنگام اتصال، تنظیمی که روی همان اینترنت جواب داده استفاده می‌شود. انتخاب دستی فرگمنت هم برای همان شبکه به خاطر سپرده می‌شود.';

  @override
  String smartSetupRemembered(String mode) {
    return 'ذخیره‌شده برای این شبکه: $mode';
  }

  @override
  String get smartSetupNotTested => 'هنوز روی این شبکه آزمایش نشده';

  @override
  String smartSetupScore(String ok, String total) {
    return '$ok از $total سرور';
  }

  @override
  String get fragmentOff => 'بدون فرگمنت';

  @override
  String get warpAdd => 'WARP رایگان کلودفلر';

  @override
  String get warpExplain =>
      'یک حساب رایگان WARP کلودفلر روی همین دستگاه می‌سازد، آن را به‌عنوان کانفیگ اضافه می‌کند و دنبال آدرسی می‌گردد که روی اینترنت شما کار کند. WARP پشتیبان خوبی است: بیشتر سایت‌ها را باز می‌کند، ولی ناشناس نیست و در ایران گاهی کند یا مسدود است.';

  @override
  String warpAdded(String endpoint) {
    return 'WARP اضافه شد (آدرس $endpoint)';
  }

  @override
  String get warpAddedNoEndpoint =>
      'WARP اضافه شد، ولی الان هیچ آدرسی جواب نداد. بعداً از منوی آن «پیدا کردن آدرس WARP» را بزنید.';

  @override
  String warpFailed(String error) {
    return 'اتصال به کلودفلر ممکن نشد ($error). اول به یک سرور وصل شوید و دوباره امتحان کنید.';
  }

  @override
  String get warpScan => 'پیدا کردن آدرس WARP';

  @override
  String warpScanDone(String endpoint) {
    return 'آدرس به $endpoint تغییر کرد';
  }

  @override
  String get warpScanNone => 'روی این شبکه هیچ آدرس WARP جواب نداد';

  @override
  String get importFromFile => 'وارد کردن فایل (‎.ovpn، JSON و…)';

  @override
  String get ciscoAdd => 'سیسکو (Cisco AnyConnect)';

  @override
  String get ciscoServer => 'آدرس سرور';

  @override
  String get ciscoGroup => 'گروه (اختیاری)';

  @override
  String get ciscoUnreachableTitle => 'سرور در دسترس نیست';

  @override
  String ciscoUnreachable(String server) {
    return 'به $server وصل نشد تا گواهی‌اش بررسی شود. باز هم اضافه شود؟';
  }

  @override
  String get ciscoUntrustedTitle => 'گواهی تأییدنشده';

  @override
  String ciscoUntrusted(String subject, String pin) {
    return 'هیچ مرجع شناخته‌شده‌ای گواهی این سرور را تأیید نکرده است؛ این در سرورهای سیسکوی خریداری‌شده رایج است. فقط اگر این سرور را فروشنده‌ی خودتان داده به آن اعتماد کنید.\n\n$subject\n$pin';
  }

  @override
  String get ciscoTrust => 'اعتماد می‌کنم';

  @override
  String get loginTitle => 'نام کاربری و رمز';

  @override
  String get loginUsername => 'نام کاربری';

  @override
  String get loginPassword => 'رمز عبور';

  @override
  String get loginUsernameRequired => 'نام کاربری را وارد کنید';

  @override
  String get loginNeeded => 'نیاز به نام کاربری و رمز';

  @override
  String get errorLoginNeeded => 'اول نام کاربری و رمز این سرور را وارد کنید';

  @override
  String get chainVia => 'اتصال از طریق سرور دیگر';

  @override
  String get chainViaHint => 'مثلاً سرور داخل ایران که هنوز به خارج راه دارد';

  @override
  String get chainPickTitle => 'سرور اول';

  @override
  String chainPickHint(String name) {
    return 'ترافیک اول به این سرور می‌رود و از آنجا به $name.';
  }

  @override
  String get chainNoOther => 'اول سرور دیگر را اضافه کنید';

  @override
  String get chainCreated => 'کانفیگ زنجیره‌ای اضافه و انتخاب شد';

  @override
  String chainThrough(String name) {
    return 'از طریق $name';
  }

  @override
  String get cdnCloudflare => 'کلودفلر';

  @override
  String get cdnArvan => 'ابرآروان';

  @override
  String get cdnArvanHint =>
      'برای کانفیگ‌هایی که پشت CDN ابرآروان هستند. آدرس‌هایش داخل ایران است و برای همین در اینترنت ملی هم اغلب کار می‌کند.';

  @override
  String get shareApp => 'فرستادن خود برنامه';

  @override
  String get shareAppHint =>
      'با بلوتوث، Nearby Share یا پیام‌رسان به گوشی دیگر بفرستید؛ اینترنت لازم نیست.';

  @override
  String get shareAppHintWindows =>
      'پوشه‌ی برنامه باز می‌شود: آن را برای کامپیوتر دیگر روی فلش کپی کنید.';

  @override
  String get shareAppTitle => 'فرستادن عاقلان قیامت';

  @override
  String get shareAppFailed =>
      'این نسخه از برنامه را نمی‌شود به‌صورت یک فایل فرستاد.';

  @override
  String get nationalTitle => 'فقط سایت‌های داخلی باز می‌شوند';

  @override
  String get nationalHint =>
      'به نظر می‌رسد اینترنت بین‌الملل قطع است (اینترنت ملی). کانفیگ‌هایی که سرورشان خارج از ایران است مستقیم وصل نمی‌شوند.';

  @override
  String get nationalHelp => 'چه کار کنم؟';

  @override
  String get nationalSheetTitle => 'در اینترنت ملی';

  @override
  String get nationalDns => 'DNS خودکار عوض شد';

  @override
  String get nationalDnsHint =>
      'DNSهای خارجی هم قطع‌اند؛ برای همین تا وقتی این وضعیت هست، نام سرورها با DNS خودِ شبکه‌ی شما پیدا می‌شود.';

  @override
  String get nationalRelay => 'از یک سرور داخل ایران رد شوید';

  @override
  String get nationalRelayHint =>
      'بعضی سرورهای دیتاسنترهای داخل ایران هنوز به خارج راه دارند. اگر کانفیگی روی چنین سروری دارید، منوی کانفیگ خارجی ← «اتصال از طریق سرور دیگر» را بزنید و آن را انتخاب کنید.';

  @override
  String get nationalCdn => 'ابرآروان برای کانفیگ‌های CDN';

  @override
  String get nationalCdnHint =>
      'کانفیگ‌هایی که پشت ابرآروان (CDN ایرانی) هستند ممکن است کار کنند: منوی کانفیگ ← «پیدا کردن IP تمیز CDN» ← ابرآروان.';

  @override
  String get nationalOffline => 'کانفیگ و برنامه بدون اینترنت';

  @override
  String get nationalOfflineHint =>
      'کانفیگ تازه را از پیام‌رسان‌های داخلی بگیرید و خود برنامه را با «فرستادن خود برنامه» از راه بلوتوث به دوستانتان بدهید.';

  @override
  String get nationalTest => 'تست کانفیگ‌ها';

  @override
  String get nationalRecheck => 'بررسی دوباره';

  @override
  String get nationalStillCut => 'هنوز فقط سایت‌های داخلی باز می‌شوند.';

  @override
  String get nationalBack => 'اینترنت بین‌الملل دوباره در دسترس است.';

  @override
  String get subscriptionHttpWarning =>
      'این آدرس رمزنگاری نشده است (http به‌جای https): ارائه‌دهنده‌ی اینترنت می‌تواند آن را ببیند و کانفیگ‌هایش را با سرورهای خودش عوض کند. اگر فروشنده لینک https دارد، از آن استفاده کنید.';

  @override
  String get freeConfig => 'کانفیگ رایگان';

  @override
  String freeConfigTitle(String network) {
    return 'کانفیگ رایگان برای $network';
  }

  @override
  String get freeConfigExplain =>
      'از WARP رایگان کلودفلر استفاده می‌کند. برنامه آدرس‌های WARP را روی اینترنت شما امتحان می‌کند، سریع‌ترین را انتخاب و برای همین اپراتور به خاطر می‌سپارد؛ با سیم‌کارت یا وای‌فای دیگر، بهترینِ آن را هم پیدا می‌کند. بار اول تا یک دقیقه طول می‌کشد.\n\nبرای سایت‌های مسدود خوب است؛ ولی ناشناس نیست و بعضی اپراتورها WARP را کند یا مسدود می‌کنند.';

  @override
  String get freeConfigStepNetwork => 'بررسی اینترنت شما…';

  @override
  String get freeConfigStepAccount => 'گرفتن حساب رایگان WARP…';

  @override
  String get freeConfigStepChecking => 'بررسی مسیری که قبلاً اینجا کار می‌کرد…';

  @override
  String freeConfigStepScanning(String network) {
    return 'پیدا کردن سریع‌ترین مسیر روی $network…';
  }

  @override
  String freeConfigName(String network) {
    return 'رایگان · $network';
  }

  @override
  String freeConfigReady(String network) {
    return 'کانفیگ رایگان برای $network آماده شد';
  }

  @override
  String freeConfigUnreachable(String network) {
    return 'الان WARP روی $network جواب نمی‌دهد؛ ممکن است اپراتور آن را بسته باشد. با اینترنت دیگری یا کمی بعد امتحان کنید.';
  }

  @override
  String get freeConfigGo => 'پیدا کن و وصل شو';
}
