import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'cloudflare_ranges.dart';

/// A CDN address that answered, with the full round trip and the data
/// centre that served it.
class CleanIpHit {
  const CleanIpHit({required this.ip, required this.latencyMs, this.colo});

  final String ip;
  final int latencyMs;

  /// Cloudflare data centre code, e.g. `FRA`.
  final String? colo;
}

/// Tests one address for [host]; `null` when it does not work.
typedef CleanIpProbe = Future<CleanIpHit?> Function(String ip, String host);

typedef CleanIpUpdate = ({String ip, CleanIpHit? hit});

/// A real check, the way a config would use the address: TCP to [ip]:443,
/// TLS with [host] as SNI, then `GET /cdn-cgi/trace` with that Host. Any
/// filtering on the way (blocked IP, SNI reset) makes it fail.
Future<CleanIpHit?> traceProbe(
  String ip,
  String host, {
  int port = 443,
  Duration timeout = const Duration(seconds: 3),
  bool allowBadCertificate = false,
}) async {
  final watch = Stopwatch()..start();
  Socket? tcp;
  SecureSocket? tls;
  try {
    tcp = await Socket.connect(ip, port, timeout: timeout);
    tls = await SecureSocket.secure(
      tcp,
      host: host,
      onBadCertificate: allowBadCertificate ? (_) => true : null,
    ).timeout(timeout);
    tls.write(
      'GET /cdn-cgi/trace HTTP/1.1\r\n'
      'Host: $host\r\n'
      'User-Agent: AghelanGhiamat\r\n'
      'Connection: close\r\n\r\n',
    );
    await tls.flush();
    final response = await utf8.decoder
        .bind(tls)
        .join()
        .timeout(timeout - watch.elapsed);
    if (!response.startsWith('HTTP/1.1 200')) return null;
    final colo = RegExp(
      r'^colo=(\w+)',
      multiLine: true,
    ).firstMatch(response)?.group(1);
    return CleanIpHit(ip: ip, latencyMs: watch.elapsedMilliseconds, colo: colo);
  } on Object {
    return null;
  } finally {
    tls?.destroy();
    tcp?.destroy();
  }
}

/// Probes a random sample of Cloudflare addresses in parallel.
class CleanIpScanner {
  CleanIpScanner({
    this.sampleSize = 300,
    this.concurrency = 24,
    CleanIpProbe? probe,
    Random? random,
  }) : _probe = probe ?? traceProbe,
       _random = random ?? Random();

  final int sampleSize;
  final int concurrency;
  final CleanIpProbe _probe;
  final Random _random;

  /// Emits one update per tested address; cancel to stop early.
  Stream<CleanIpUpdate> scan(String host) {
    final targets = sample(sampleSize, _random);
    var next = 0;
    var cancelled = false;
    late final StreamController<CleanIpUpdate> updates;

    Future<void> worker() async {
      while (!cancelled && next < targets.length) {
        final ip = targets[next++];
        final hit = await _probe(ip, host);
        if (cancelled) return;
        updates.add((ip: ip, hit: hit));
      }
    }

    updates = StreamController<CleanIpUpdate>(
      onListen: () => unawaited(
        Future.wait([
          for (var i = 0; i < min(concurrency, targets.length); i++) worker(),
        ]).whenComplete(() {
          if (!cancelled) unawaited(updates.close());
        }),
      ),
      onCancel: () => cancelled = true,
    );
    return updates.stream;
  }

  /// [count] distinct addresses spread over the ranges by their size,
  /// skipping network and broadcast-looking ones.
  static List<String> sample(int count, Random random) {
    final ranges = [for (final cidr in cloudflareIpv4Ranges) _parse(cidr)];
    final total = ranges.fold<int>(0, (sum, r) => sum + r.size);
    final picked = <String>{};
    while (picked.length < count) {
      var offset = random.nextInt(total);
      for (final range in ranges) {
        if (offset < range.size) {
          final value = range.base + offset;
          final last = value & 0xFF;
          if (last != 0 && last != 255) picked.add(_format(value));
          break;
        }
        offset -= range.size;
      }
    }
    return picked.toList();
  }

  static ({int base, int size}) _parse(String cidr) {
    final [address, bits] = cidr.split('/');
    final value = address
        .split('.')
        .map(int.parse)
        .fold<int>(0, (acc, octet) => (acc << 8) | octet);
    return (base: value, size: 1 << (32 - int.parse(bits)));
  }

  static String _format(int value) => [
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ].join('.');
}
