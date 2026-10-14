import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../../../core/singbox/link_parser.dart';
import '../../../core/singbox/proxy_config.dart';
import '../../clean_ip/data/clean_ip_scanner.dart';
import '../../profiles/data/subscription_client.dart';
import 'x25519.dart';

/// A free Cloudflare WARP device registration: what the WireGuard config
/// needs.
class WarpAccount {
  const WarpAccount({
    required this.privateKey,
    required this.peerPublicKey,
    required this.addressV4,
    this.addressV6,
    required this.reserved,
  });

  final String privateKey;
  final String peerPublicKey;
  final String addressV4;
  final String? addressV6;

  /// The 3 "reserved" bytes WARP expects in each WireGuard packet.
  final List<int> reserved;

  /// Cloudflare's default WARP endpoint.
  static const defaultEndpoint = (host: '162.159.192.1', port: 2408);

  /// The config as a `wireguard://` link (shareable, re-importable).
  String link({String host = '162.159.192.1', int port = 2408}) {
    final addresses = [
      '$addressV4/32',
      if (addressV6 != null) '$addressV6/128',
    ].join(',');
    final query = [
      'publickey=${Uri.encodeQueryComponent(peerPublicKey)}',
      'address=${Uri.encodeQueryComponent(addresses)}',
      'reserved=${reserved.join(',')}',
      'mtu=1280',
      'keepalive=25',
    ].join('&');
    final hostPart = host.contains(':') ? '[$host]' : host;
    return 'wireguard://${Uri.encodeComponent(privateKey)}@$hostPart:$port?$query#WARP';
  }

  ProxyConfig config({String host = '162.159.192.1', int port = 2408}) =>
      LinkParser.parse(link(host: host, port: port));
}

class WarpException implements Exception {
  const WarpException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Finds reachable Cloudflare edge IPs for [host] when its own address is
/// blocked; fastest scan hits first, empty when none are found.
typedef CleanIpFinder = Future<List<String>> Function(String host);

/// Registers a new WARP device with Cloudflare's client API, as the
/// official app does.
class WarpClient {
  WarpClient(
    this._client, {
    this.api = defaultApi,
    this.cleanIps,
    http.Client Function(String ip)? clientForIp,
  }) : _clientForIp = clientForIp ?? _pinnedClient;

  static const defaultApi = 'https://api.cloudflareclient.com/v0a2158';
  static const _timeout = Duration(seconds: 8);
  static const _headers = {
    'User-Agent': 'okhttp/3.12.1',
    'CF-Client-Version': 'a-6.10-2158',
    'Content-Type': 'application/json; charset=UTF-8',
  };

  final http.Client _client;
  final String api;

  /// Supplies clean Cloudflare edge IPs when the API's own address is blocked.
  final CleanIpFinder? cleanIps;

  /// Builds a client whose TCP goes to a given IP while TLS and the request
  /// keep the API's hostname.
  final http.Client Function(String ip) _clientForIp;

  Future<WarpAccount> register({Random? random, DateTime? now}) async {
    final (private, public) = generateKeyPair(random);
    final body = jsonEncode({
      'install_id': '',
      'fcm_token': '',
      'tos': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'key': base64.encode(public),
      'type': 'Android',
      'model': 'PC',
      'locale': 'en_US',
    });

    Future<WarpAccount> over(http.Client client) async => _account(
      await client
          .post(Uri.parse('$api/reg'), headers: _headers, body: body)
          .timeout(_timeout),
      private,
    );

    // Directly first: instant where api.cloudflareclient.com is reachable
    // (abroad, or with a tunnel already up).
    try {
      return await over(_client);
    } on Exception catch (direct) {
      // Its address is blocked (e.g. Iran, no tunnel yet): reach it over a
      // clean Cloudflare edge IP. The whole edge serves the API, so any
      // reachable IP works while SNI and Host stay the real hostname, which
      // steps around DNS poisoning and the blocking of its own addresses.
      final finder = cleanIps;
      if (finder == null) throw WarpException(direct.toString());
      for (final ip in await finder(Uri.parse(api).host)) {
        final client = _clientForIp(ip);
        try {
          return await over(client);
        } on Exception {
          // Try the next clean IP.
        } finally {
          client.close();
        }
      }
      throw WarpException(direct.toString());
    }
  }

  WarpAccount _account(http.Response response, List<int> private) {
    if (response.statusCode != 200) {
      throw WarpException('HTTP ${response.statusCode}');
    }
    final Object? json;
    try {
      json = jsonDecode(response.body);
    } on FormatException {
      throw const WarpException('unexpected answer');
    }
    final config = json is Map ? json['config'] : null;
    if (config is! Map) throw const WarpException('unexpected answer');
    final peers = config['peers'];
    final peer = peers is List && peers.isNotEmpty ? peers.first : null;
    final addresses = (config['interface'] as Map?)?['addresses'] as Map?;
    final peerKey = peer is Map ? peer['public_key'] : null;
    final v4 = addresses?['v4'];
    if (peerKey is! String || v4 is! String) {
      throw const WarpException('unexpected answer');
    }
    final clientId = config['client_id'];
    var reserved = const [0, 0, 0];
    if (clientId is String) {
      try {
        final bytes = base64.decode(base64.normalize(clientId));
        if (bytes.length == 3) reserved = bytes;
      } on FormatException {
        // Keep zeros.
      }
    }
    return WarpAccount(
      privateKey: base64.encode(private),
      peerPublicKey: peerKey,
      addressV4: v4,
      addressV6: addresses?['v6'] as String?,
      reserved: reserved,
    );
  }

  /// A client pinned to [ip]: the TCP connection goes there, but TLS uses the
  /// request's hostname for SNI and the certificate check.
  static http.Client _pinnedClient(String ip) {
    final io = HttpClient()..connectionTimeout = _timeout;
    io.connectionFactory = (uri, proxyHost, proxyPort) =>
        Socket.startConnect(ip, uri.port);
    return IOClient(io);
  }
}

final warpClientProvider = Provider<WarpClient>(
  (ref) =>
      WarpClient(ref.watch(httpClientProvider), cleanIps: _cleanCloudflareIps),
);

/// Scans for reachable Cloudflare edge IPs that can serve [host], the same
/// way the app finds clean IPs for configs; returns up to a few.
Future<List<String>> _cleanCloudflareIps(String host) async {
  final scanner = CleanIpScanner(sampleSize: 150, concurrency: 24);
  final ips = <String>[];
  final enough = Completer<void>();
  final sub = scanner.scan(host).listen(
    (update) {
      if (update.hit == null) return;
      ips.add(update.hit!.ip);
      if (ips.length >= 3 && !enough.isCompleted) enough.complete();
    },
    onDone: () {
      if (!enough.isCompleted) enough.complete();
    },
  );
  try {
    await enough.future.timeout(const Duration(seconds: 12));
  } on TimeoutException {
    // Use whatever answered in time.
  } finally {
    await sub.cancel();
  }
  return ips;
}

/// Cloudflare's WARP peer key: marks a WireGuard config as WARP.
const warpPeerKey = 'bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=';

bool isWarp(ProxyConfig config) {
  final peers = config.outbound['peers'];
  return config.protocol == ProxyProtocol.wireguard &&
      peers is List &&
      peers.isNotEmpty &&
      (peers.first as Map)['public_key'] == warpPeerKey;
}

/// Address ranges and ports WARP answers on; filtering often blocks only
/// some of them.
const warpRanges = [
  '162.159.192',
  '162.159.193',
  '162.159.195',
  '188.114.96',
  '188.114.97',
  '188.114.98',
  '188.114.99',
];

const warpPorts = [
  2408, 500, 1701, 4500, 854, 859, 864, 878, 880, 890, 891, 894, 903, 908, //
  928, 934, 939, 942, 943, 945, 946, 955, 968, 987, 988, 1002, 1010, 1014,
  1018, 1070, 1074, 1180, 1387, 1843, 2371, 2506, 3138, 3476, 3581, 3854,
  4177, 4198, 4233, 5279, 5956, 7103, 7152, 7156, 7281, 7559, 8319, 8742,
  8854, 8886,
];

/// [count] distinct random endpoints, always including the default one.
List<({String host, int port})> sampleWarpEndpoints(
  int count, [
  Random? random,
]) {
  final rng = random ?? Random();
  final picked = <String>{};
  final result = <({String host, int port})>[WarpAccount.defaultEndpoint];
  picked.add(
    '${WarpAccount.defaultEndpoint.host}:${WarpAccount.defaultEndpoint.port}',
  );
  while (result.length < count) {
    final host =
        '${warpRanges[rng.nextInt(warpRanges.length)]}.${1 + rng.nextInt(254)}';
    final port = warpPorts[rng.nextInt(warpPorts.length)];
    if (picked.add('$host:$port')) result.add((host: host, port: port));
  }
  return result;
}

/// [config] with its WireGuard peer at [host]:[port].
ProxyConfig withEndpoint(ProxyConfig config, String host, int port) {
  final outbound = (jsonDecode(jsonEncode(config.outbound)) as Map)
      .cast<String, Object?>();
  final peers = outbound['peers']! as List;
  final peer = (peers.first as Map)
    ..['address'] = host
    ..['port'] = port;
  peers[0] = peer;
  return ProxyConfig(
    protocol: config.protocol,
    name: config.name,
    server: host,
    port: port,
    outbound: outbound,
  );
}
