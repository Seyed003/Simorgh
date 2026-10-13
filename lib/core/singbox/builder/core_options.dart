import 'dart:convert';

enum CorePlatform { android, windows, other }

/// How the TLS ClientHello of proxy connections is split so that simple
/// SNI filters cannot read the server name.
enum TlsFragmentMode {
  off,

  /// Several TLS records in one packet (`record_fragment`); almost free.
  record,

  /// Separate TCP segments with short pauses (`fragment`); stronger, slower.
  tcp,
}

/// Android per-app split tunneling.
enum PerAppMode {
  /// Every app uses the tunnel.
  off,

  /// Only the selected apps use the tunnel.
  include,

  /// The selected apps bypass the tunnel.
  exclude,
}

/// Multiplex protocols sing-box can speak to a server.
const muxProtocols = ['h2mux', 'smux', 'yamux'];

/// Tunables that shape the generated sing-box config. Persisted by the
/// settings feature and passed to [SingBoxConfigBuilder].
class CoreOptions {
  const CoreOptions({
    this.logLevel = 'warn',
    this.remoteDns = 'https://1.1.1.1/dns-query',
    this.directDns = '1.1.1.1',
    this.enableIpv6 = false,
    this.tunStack = 'mixed',
    this.mtu = 9000,
    this.strictRoute = true,
    this.mixedPort,
    this.sniff = true,
    this.defaultFingerprint = 'chrome',
    this.bypassIran = true,
    this.tlsFragment = TlsFragmentMode.off,
    this.mux = false,
    this.muxProtocol = 'h2mux',
    this.perAppMode = PerAppMode.off,
    this.perAppPackages = const [],
    this.blockQuic = true,
    this.mixedAuth = true,
    this.mixedPassword,
  });

  /// User name of the local proxy when [mixedAuth] is on.
  static const mixedUsername = 'aghelan';

  static const logLevels = [
    'trace',
    'debug',
    'info',
    'warn',
    'error',
    'fatal',
    'panic',
  ];
  static const tunStacks = ['mixed', 'gvisor', 'system'];

  final String logLevel;

  /// DNS used for proxied lookups, sent through the tunnel. Accepts
  /// `https://`, `h3://`, `tls://`, `quic://`, `tcp://`, `udp://`, a bare IP
  /// or `local`.
  final String remoteDns;

  /// DNS used to resolve proxy server hostnames, sent directly.
  final String directDns;
  final bool enableIpv6;
  final String tunStack;
  final int mtu;
  final bool strictRoute;

  /// Local HTTP+SOCKS5 proxy port on 127.0.0.1, `null` to disable it.
  final int? mixedPort;
  final bool sniff;

  /// uTLS fingerprint applied to TCP TLS outbounds that do not set one;
  /// `null` keeps Go's native TLS fingerprint.
  final String? defaultFingerprint;

  /// Send Iranian sites (`.ir`, well-known Iranian services and Iranian IP
  /// ranges) directly instead of through the proxy.
  final bool bypassIran;

  /// Applied to TCP TLS outbounds (Reality included) that do not set it.
  final TlsFragmentMode tlsFragment;

  /// Multiplex VMess/VLESS/Trojan/Shadowsocks connections over a few TCP
  /// connections. The server must support sing-box style multiplex.
  final bool mux;
  final String muxProtocol;

  /// Android only: which apps go through the tunnel.
  final PerAppMode perAppMode;
  final List<String> perAppPackages;

  /// Reject QUIC (UDP 443) to proxied destinations so apps use TCP, which
  /// is much faster through TCP-based proxies.
  final bool blockQuic;

  /// The local proxy asks for [mixedUsername] and [mixedPassword], so other
  /// apps on the device cannot use it (or learn the server) on their own.
  final bool mixedAuth;
  final String? mixedPassword;

  /// Credentials the local proxy requires, `null` when it is open.
  ({String username, String password})? get mixedCredentials =>
      mixedAuth && mixedPassword != null && mixedPassword!.isNotEmpty
      ? (username: mixedUsername, password: mixedPassword!)
      : null;

  CoreOptions copyWith({
    String? logLevel,
    String? remoteDns,
    String? directDns,
    bool? enableIpv6,
    String? tunStack,
    int? mtu,
    bool? strictRoute,
    int? Function()? mixedPort,
    bool? sniff,
    String? Function()? defaultFingerprint,
    bool? bypassIran,
    TlsFragmentMode? tlsFragment,
    bool? mux,
    String? muxProtocol,
    PerAppMode? perAppMode,
    List<String>? perAppPackages,
    bool? blockQuic,
    bool? mixedAuth,
    String? mixedPassword,
  }) {
    return CoreOptions(
      logLevel: logLevel ?? this.logLevel,
      remoteDns: remoteDns ?? this.remoteDns,
      directDns: directDns ?? this.directDns,
      enableIpv6: enableIpv6 ?? this.enableIpv6,
      tunStack: tunStack ?? this.tunStack,
      mtu: mtu ?? this.mtu,
      strictRoute: strictRoute ?? this.strictRoute,
      mixedPort: mixedPort != null ? mixedPort() : this.mixedPort,
      sniff: sniff ?? this.sniff,
      defaultFingerprint: defaultFingerprint != null
          ? defaultFingerprint()
          : this.defaultFingerprint,
      bypassIran: bypassIran ?? this.bypassIran,
      tlsFragment: tlsFragment ?? this.tlsFragment,
      mux: mux ?? this.mux,
      muxProtocol: muxProtocol ?? this.muxProtocol,
      perAppMode: perAppMode ?? this.perAppMode,
      perAppPackages: perAppPackages ?? this.perAppPackages,
      blockQuic: blockQuic ?? this.blockQuic,
      mixedAuth: mixedAuth ?? this.mixedAuth,
      mixedPassword: mixedPassword ?? this.mixedPassword,
    );
  }

  Map<String, Object?> toJson() => {
    'logLevel': logLevel,
    'remoteDns': remoteDns,
    'directDns': directDns,
    'enableIpv6': enableIpv6,
    'tunStack': tunStack,
    'mtu': mtu,
    'strictRoute': strictRoute,
    'mixedPort': mixedPort,
    'sniff': sniff,
    'defaultFingerprint': defaultFingerprint,
    'bypassIran': bypassIran,
    'tlsFragment': tlsFragment.name,
    'mux': mux,
    'muxProtocol': muxProtocol,
    'perAppMode': perAppMode.name,
    'perAppPackages': perAppPackages,
    'blockQuic': blockQuic,
    'mixedAuth': mixedAuth,
    'mixedPassword': mixedPassword,
  };

  factory CoreOptions.fromJson(
    Map<String, Object?> json, {
    CoreOptions? defaults,
  }) {
    final d = defaults ?? const CoreOptions();
    return CoreOptions(
      logLevel: json['logLevel'] as String? ?? d.logLevel,
      remoteDns: json['remoteDns'] as String? ?? d.remoteDns,
      directDns: json['directDns'] as String? ?? d.directDns,
      enableIpv6: json['enableIpv6'] as bool? ?? d.enableIpv6,
      tunStack: json['tunStack'] as String? ?? d.tunStack,
      mtu: json['mtu'] as int? ?? d.mtu,
      strictRoute: json['strictRoute'] as bool? ?? d.strictRoute,
      mixedPort: json.containsKey('mixedPort')
          ? json['mixedPort'] as int?
          : d.mixedPort,
      sniff: json['sniff'] as bool? ?? d.sniff,
      defaultFingerprint: json.containsKey('defaultFingerprint')
          ? json['defaultFingerprint'] as String?
          : d.defaultFingerprint,
      bypassIran: json['bypassIran'] as bool? ?? d.bypassIran,
      tlsFragment:
          TlsFragmentMode.values.asNameMap()[json['tlsFragment']] ??
          d.tlsFragment,
      mux: json['mux'] as bool? ?? d.mux,
      muxProtocol: muxProtocols.contains(json['muxProtocol'])
          ? json['muxProtocol']! as String
          : d.muxProtocol,
      perAppMode:
          PerAppMode.values.asNameMap()[json['perAppMode']] ?? d.perAppMode,
      perAppPackages: json['perAppPackages'] is List
          ? (json['perAppPackages']! as List).whereType<String>().toList()
          : d.perAppPackages,
      blockQuic: json['blockQuic'] as bool? ?? d.blockQuic,
      mixedAuth: json['mixedAuth'] as bool? ?? d.mixedAuth,
      mixedPassword: json['mixedPassword'] as String? ?? d.mixedPassword,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CoreOptions &&
      jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

/// Where the core exposes its Clash-compatible API for traffic stats.
class ClashApiOptions {
  const ClashApiOptions({required this.port, required this.secret});

  final int port;
  final String secret;

  String get controller => '127.0.0.1:$port';
}
