import 'dart:async';
import 'dart:io';

/// How far the device gets without the VPN.
enum InternetReach {
  /// Foreign sites answer.
  open,

  /// Only Iranian addresses answer: the international link is cut
  /// ("national internet").
  domesticOnly,

  /// Nothing answers.
  offline,
}

/// Whether [target] answers: `tcp://host:port` needs a TCP connection,
/// `http(s)://` any HTTP response (with a valid certificate for https).
typedef ReachCheck = Future<bool> Function(Uri target, Duration timeout);

/// Tells the national internet apart from an open or a dead connection by
/// trying a few well-known foreign and Iranian addresses directly.
class ReachProbe {
  const ReachProbe({
    this.check = reachable,
    this.foreign = foreignTargets,
    this.domestic = domesticTargets,
    this.timeout = const Duration(seconds: 5),
  });

  final ReachCheck check;
  final List<String> foreign;
  final List<String> domestic;
  final Duration timeout;

  /// Reachable from Iran in normal times; one of them is an IP address so a
  /// foreign DNS that is cut off too does not decide the result.
  static const foreignTargets = [
    'https://1.1.1.1/cdn-cgi/trace',
    'https://www.gstatic.com/generate_204',
    'https://cp.cloudflare.com/generate_204',
  ];

  /// Iranian DNS servers (by address, no lookup needed) and sites. Only a
  /// TCP connection, no request: Iranian services learn nothing about the
  /// app.
  static const domesticTargets = [
    'tcp://178.22.122.100:53',
    'tcp://78.157.42.100:53',
    'tcp://www.aparat.com:443',
    'tcp://www.digikala.com:443',
  ];

  Future<InternetReach> run() async {
    final abroad = _any(foreign);
    final home = _any(domestic);
    if (await abroad) return InternetReach.open;
    return await home ? InternetReach.domesticOnly : InternetReach.offline;
  }

  /// True as soon as one target answers; false when none does.
  Future<bool> _any(List<String> targets) {
    final result = Completer<bool>();
    var pending = targets.length;
    if (pending == 0) return Future.value(false);
    void done(bool ok) {
      pending--;
      if (result.isCompleted) return;
      if (ok) {
        result.complete(true);
      } else if (pending == 0) {
        result.complete(false);
      }
    }

    for (final target in targets) {
      unawaited(
        check(
          Uri.parse(target),
          timeout,
        ).catchError((Object _) => false).then(done),
      );
    }
    return result.future;
  }
}

/// The real [ReachCheck], straight from the device (no system proxy).
Future<bool> reachable(Uri target, Duration timeout) async {
  if (target.scheme == 'tcp') {
    try {
      final socket = await Socket.connect(
        target.host,
        target.port,
        timeout: timeout,
      );
      socket.destroy();
      return true;
    } on Object {
      return false;
    }
  }
  final client = HttpClient()
    ..connectionTimeout = timeout
    ..findProxy = ((_) => 'DIRECT')
    // Nothing that names the app.
    ..userAgent = null;
  try {
    final request = await client.getUrl(target).timeout(timeout);
    request.followRedirects = false;
    final response = await request.close().timeout(timeout);
    unawaited(response.drain<void>().catchError((Object _) {}));
    return true;
  } on Object {
    return false;
  } finally {
    client.close(force: true);
  }
}
