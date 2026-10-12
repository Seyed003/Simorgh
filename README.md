<div align="center">

<img src="assets/branding/app_icon.png" width="112" alt="Aghelan Ghiamat icon">

# Aghelan Ghiamat · عاقلان قیامت

Open-source VPN client for **Android** and **Windows**, powered by the
[sing-box](https://github.com/SagerNet/sing-box) core.

[فارسی](#فارسی) · [English](#english)

</div>

---

## English

### Features

- **Protocols:** VMess, VLESS (incl. REALITY + XTLS-Vision), Trojan,
  Shadowsocks (SIP002, 2022 ciphers, legacy, obfs/v2ray plugins), Hysteria2
  (incl. port hopping), TUIC, WireGuard, SSH — plus Hysteria v1, AnyTLS and
  SOCKS.
- **Transports:** TCP, WebSocket (with early data), gRPC, HTTP/2, HTTPUpgrade,
  QUIC, TCP+HTTP header obfuscation. Xray-only transports (xhttp, mKCP) are
  reported clearly instead of failing silently.
- **Import from anywhere:** share links, clipboard, camera QR (Android), QR
  from an image/screenshot (Android + Windows), pasted text, subscription URLs
  (base64 or plain), and sing-box JSON configs/outbounds.
- **Subscriptions:** quota/expiry from `subscription-userinfo`, panel titles,
  one-tap update that keeps your selected server.
- **Full-device tunnel:** Android `VpnService` via libbox; Windows TUN
  (wintun) via `sing-box.exe` with admin rights, tray icon and close-to-tray.
- **Live stats:** connection timer and upload/download speed and totals from
  the core's Clash API.
- **Real latency test:** tests every server through the proxy itself (an
  HTTPS request timed by a separate sing-box test core, so it works with or
  without the VPN on), shows per-server ms badges, sorts fastest first, and
  skips configs the core rejects instead of failing the whole run.
- **Auto mode (fastest server + failover):** picks the fastest servers from
  recent latency results (testing first if they are missing or older than an
  hour) and hands up to 10 of them to the core as a `urltest` group. The core
  re-tests them every minute and moves to another server when the current one
  stops answering; the home screen shows which server is in use.
- **Iranian sites without VPN (on by default):** `.ir` domains, well-known
  Iranian services and every IP range RIPE has delegated to Iran go direct and
  are resolved by the direct DNS. Faster, saves VPN traffic, and Iranian banks
  and government sites that block foreign IPs keep working. The ranges are
  built into the app (no download at connect time); refresh them with
  `python3 scripts/update_iran_ip_ranges.py`.
- **Anti-filtering options:** TLS fragment (*Light* splits the ClientHello
  into several TLS records, *Strong* into separate TCP segments) so simple SNI
  filters cannot read the server name, and Mux (h2mux/smux/yamux) for
  VMess/VLESS/Trojan/Shadowsocks servers that support it. Both are applied to
  every server that does not set them itself, latency tests included.
- **Persian + English** with full right-to-left layout, light/dark themes,
  bundled Vazirmatn font.
- **Connection settings:** remote/direct DNS (DoH, DoT, DoQ, UDP, system),
  IPv6, uTLS fingerprint, TUN stack, local HTTP/SOCKS port, log level.
- **No proprietary SDKs:** QR scanning uses the official camera plugin and a
  pure-Dart decoder (no Google ML Kit), so the app is F-Droid friendly.

### Project layout

```
lib/
  core/
    singbox/          share-link + subscription parsers, sing-box config builder
    theme/ utils/ widgets/ storage/ constants/
  features/
    home/             connect button, status, speeds
    profiles/         configs, subscriptions, import flows, QR scanner
    connection/       VPN state, Android/Windows platforms, Clash API client
    settings/         language, theme, connection options
    desktop/          Windows tray + window behaviour
  l10n/               app_en.arb, app_fa.arb (+ generated code)
android/app/src/main/kotlin/com/aghelan/ghiamat/vpn/
                      VpnService + libbox PlatformInterface, Flutter bridge
windows/              runner (admin manifest, single instance), core/sing-box.exe
scripts/              build/fetch the sing-box core, icon generator
test/                 unit, widget and real-core integration tests
```

State management is [Riverpod 3](https://riverpod.dev). The sing-box version
is pinned in `scripts/core_version.txt` (currently **1.14.3**).

### Requirements

| Tool | Version |
|------|---------|
| Flutter | 3.47.x (stable) |
| Go | 1.25+ (Android core only) |
| JDK | 17+ |
| Android SDK + NDK | platform 36, NDK 28.2.13676358 |
| Windows | Windows 10/11 x64, Visual Studio 2022 with "Desktop development with C++" |

### Build for Android

`scripts/build_libbox.sh` is a bash script: on a Windows machine run it from
WSL or Git Bash (or let CI build it, see below).

```bash
# 1. Build the sing-box core for Android (libbox.aar, ~5–10 min the first time)
export ANDROID_HOME=$HOME/Android/Sdk          # your SDK path
sdkmanager "ndk;28.2.13676358"
scripts/build_libbox.sh                         # -> android/app/libs/libbox.aar
#   only arm64 (faster, for testing):  scripts/build_libbox.sh android/arm64

# 2. Build the app
flutter pub get
flutter build apk --release --split-per-abi     # -> build/app/outputs/flutter-apk/
#   or run on a device:  flutter run
```

**Release signing:** create `android/key.properties`

```properties
storeFile=/absolute/path/to/release.jks
storePassword=...
keyAlias=...
keyPassword=...
```

Without it, release builds are signed with the debug key.

A release APK for one ABI is about 30 MB (the sing-box core is ~20 MB of it).

### Build for Windows

Enable **Developer Mode** in Windows settings first (Flutter needs symlinks
for plugins), then run these in PowerShell:

```powershell
# 1. Download sing-box.exe into windows\core\
powershell -ExecutionPolicy Bypass -File scripts\fetch_core_windows.ps1
#    (if GitHub is blocked: bash scripts/build_core_windows.sh builds it from source)

# 2. Build
flutter pub get
flutter build windows --release
# Output: build\windows\x64\runner\Release\  (ship the whole folder)
```

The app requests administrator rights at launch (TUN needs them). Because of
that, `flutter run` must be started from an **elevated** terminal or IDE.
Closing the window minimises it to the tray; use the tray menu → *Quit* to exit
(which also stops the core).

### CI builds

`.github/workflows/build.yml` runs analysis and tests, validates every
generated config with the real sing-box binary, then builds the Android APKs
and a Windows zip as downloadable artifacts. Push to `main` (or run the
workflow manually) and grab the files from the run's *Artifacts* section.

### Tests

```bash
flutter test                                              # unit + widget tests
SING_BOX_BIN=/path/to/sing-box flutter test --tags singbox  # validate configs with the real core
SCREENSHOTS=1 flutter test test/screenshots               # render UI screenshots to build/screenshots
```

### Roadmap (phase 2)

~~Real ping test of all servers~~ (done) · ~~auto-select best server +
failover~~ (done) · ~~Iran routing rules (domestic direct)~~ (done) · ~~TLS fragment~~ (done) ·
~~Mux~~ (done) · speed test · per-app split tunnel · DoH presets · Cloudflare clean-IP scanner · usage charts · Android Quick
Settings tile and widget · scheduled subscription updates.

### License

GPL-3.0-or-later. sing-box is GPL-3.0-or-later; parts of the Android service
are adapted from [sing-box-for-android](https://github.com/SagerNet/sing-box-for-android)
(GPL-3.0). The Vazirmatn font is under the SIL Open Font License 1.1
(`assets/fonts/Vazirmatn-OFL.txt`).

---

<div dir="rtl">

## فارسی

### امکانات

- **پروتکل‌ها:** VMess، VLESS (همراه REALITY و XTLS-Vision)، Trojan،
  Shadowsocks (SIP002، رمزهای ۲۰۲۲، قالب قدیمی، پلاگین obfs و v2ray)،
  Hysteria2 (با port hopping)، TUIC، WireGuard، SSH و علاوه بر این‌ها
  Hysteria نسخه ۱، AnyTLS و SOCKS.
- **ترنسپورت‌ها:** TCP، WebSocket، gRPC، HTTP/2، HTTPUpgrade، QUIC. اگر
  کانفیگی از ترنسپورت‌های مخصوص Xray (مثل xhttp یا mKCP) استفاده کند، دلیلش
  به‌روشنی نمایش داده می‌شود.
- **وارد کردن از همه‌جا:** لینک اشتراک، کلیپ‌بورد، اسکن QR با دوربین
  (اندروید)، QR از روی عکس یا اسکرین‌شات (اندروید و ویندوز)، متن چسبانده‌شده،
  لینک سابسکریپشن (base64 یا متن ساده) و JSON سینگ‌باکس.
- **سابسکریپشن:** نمایش حجم مصرفی و تاریخ انقضا، به‌روزرسانی با یک لمس بدون
  از دست رفتن سرور انتخاب‌شده.
- **تونل کامل دستگاه:** در اندروید با VpnService و در ویندوز با حالت TUN
  (همراه آیکون سینی سیستم).
- **آمار زنده:** زمان اتصال و سرعت آپلود/دانلود.
- **تست پینگ واقعی:** همه‌ی سرورها از داخل خود پراکسی تست می‌شوند (چه VPN
  روشن باشد چه خاموش)، کنار هر سرور عدد پینگ نمایش داده می‌شود و می‌توان
  سرورها را از سریع‌ترین مرتب کرد.
- **حالت خودکار (سریع‌ترین سرور):** برنامه سریع‌ترین سرورها را انتخاب می‌کند
  و اگر سرور فعلی قطع شد، خودش به سرور سالم بعدی می‌رود. در صفحه اصلی نمایش
  داده می‌شود که الان از کدام سرور استفاده می‌شود.
- **سایت‌های ایرانی بدون VPN (به‌طور پیش‌فرض روشن):** دامنه‌های `.ir`،
  سرویس‌های معروف ایرانی و همه‌ی IPهای ایران مستقیم باز می‌شوند؛ سریع‌تر است،
  حجم VPN مصرف نمی‌شود و سایت‌های بانکی و دولتی هم کار می‌کنند. از تنظیمات
  «اتصال» قابل خاموش کردن است.
- **ضدفیلتر:** فرگمنت TLS («سبک» و «قوی») تا فیلترینگ نتواند نام سرور را
  بخواند، و Mux برای سرورهایی که پشتیبانی می‌کنند. هر دو در تنظیمات «اتصال»
  هستند و به‌طور پیش‌فرض خاموش‌اند.
- **فارسی و انگلیسی** با چیدمان کامل راست‌به‌چپ، تم روشن و تیره و فونت وزیرمتن.
- **بدون SDK اختصاصی گوگل**؛ مناسب برای انتشار در F-Droid.

### ساخت نسخه اندروید

```bash
# ۱. ساخت هسته sing-box برای اندروید (فایل libbox.aar)
export ANDROID_HOME=$HOME/Android/Sdk
sdkmanager "ndk;28.2.13676358"
scripts/build_libbox.sh

# ۲. ساخت برنامه
flutter pub get
flutter build apk --release --split-per-abi
# خروجی: build/app/outputs/flutter-apk/
```

اسکریپت `build_libbox.sh` با bash اجرا می‌شود؛ اگر روی ویندوز هستید آن را در
WSL یا Git Bash اجرا کنید. برای امضای نسخه نهایی، فایل `android/key.properties`
را مطابق بخش انگلیسی بسازید.

### ساخت نسخه ویندوز

ابتدا **Developer Mode** را در تنظیمات ویندوز روشن کنید، سپس در PowerShell:

```powershell
# ۱. دانلود sing-box.exe در پوشه windows\core
powershell -ExecutionPolicy Bypass -File scripts\fetch_core_windows.ps1

# ۲. ساخت برنامه
flutter pub get
flutter build windows --release
# خروجی: build\windows\x64\runner\Release (کل پوشه را منتشر کنید)
```

برنامه هنگام اجرا دسترسی Administrator می‌خواهد (حالت TUN به آن نیاز دارد).
بستن پنجره، برنامه را به سینی سیستم می‌برد؛ برای خروج کامل از منوی آیکون
گزینه «خروج» را بزنید.

### ساخت خودکار با GitHub Actions

با هر push به شاخه `main`، فایل‌های APK اندروید و فایل zip ویندوز به‌صورت
خودکار ساخته می‌شوند و در بخش *Artifacts* همان اجرا قابل دانلودند.

### مجوز

GPL-3.0-or-later

</div>
