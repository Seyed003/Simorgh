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
}
