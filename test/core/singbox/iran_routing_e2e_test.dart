@Tags(['singbox'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:aghelan_ghiamat/core/singbox/builder/config_builder.dart';
import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Future<int> _freePort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = s.port;
  await s.close();
  return port;
}

/// Sends requests through the real core's local proxy and reads its debug
/// log to see which outbound each one was routed to:
///
///     SING_BOX_BIN=/path/to/sing-box flutter test --tags singbox
void main() {
  final binary = Platform.environment['SING_BOX_BIN'];
  final skip = binary == null || !File(binary).existsSync()
      ? 'set SING_BOX_BIN to a sing-box executable to run'
      : null;

  /// Host -> outbound tag the core picked for it.
  Future<Map<String, String>> route(
    CoreOptions options,
    List<String> urls,
  ) async {
    final dir = await Directory.systemTemp.createTemp('iran-routing');
    addTearDown(() => dir.delete(recursive: true));
    final port = await _freePort();
    // The "proxy" is a dead local server: only the routing decision matters.
    final config = SingBoxConfigBuilder(
      options: options.copyWith(
        mixedPort: () => port,
        logLevel: 'debug',
        directDns: '127.0.0.1',
      ),
      platform: CorePlatform.other,
    ).buildJson(LinkParser.parse('ss://YWVzLTEyOC1nY206eA@127.0.0.1:1#dead'));
    final file = File('${dir.path}/config.json')..writeAsStringSync(config);
    final process = await Process.start(binary!, [
      'run',
      '-c',
      file.path,
      '-D',
      dir.path,
      '--disable-color',
    ]);
    addTearDown(process.kill);

    final routes = <String, String>{};
    final pattern = RegExp(
      r'outbound/\w+\[([\w-]+)\]: outbound connection to (\[?[\w.:-]+?\]?):\d+$',
    );
    for (final stream in [process.stdout, process.stderr]) {
      stream.transform(utf8.decoder).transform(const LineSplitter()).listen((
        line,
      ) {
        final match = pattern.firstMatch(line.trim());
        if (match != null) routes[match.group(2)!] = match.group(1)!;
      });
    }
    for (var i = 0; i < 50; i++) {
      try {
        await (await Socket.connect('127.0.0.1', port)).close();
        break;
      } on SocketException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }

    final client = HttpClient()
      ..findProxy = ((_) => 'PROXY 127.0.0.1:$port')
      ..connectionTimeout = const Duration(seconds: 2);
    addTearDown(() => client.close(force: true));
    await Future.wait([
      for (final url in urls)
        () async {
          try {
            final request = await client.getUrl(Uri.parse(url));
            await (await request.close().timeout(const Duration(seconds: 2)))
                .drain<void>();
          } on Object {
            // Nothing answers; the log already has the decision.
          }
        }(),
    ]);
    final hosts = urls.map((u) => Uri.parse(u).host).toSet();
    for (var i = 0; i < 50 && !hosts.every(routes.containsKey); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return routes;
  }

  const urls = [
    'http://2.176.0.1/', // Iranian mobile operator range
    'http://divar.ir/',
    'http://www.digikala.com/',
    'http://example.com/',
    'http://8.8.8.8/',
  ];

  test(
    'Iranian sites go direct, the rest through the proxy',
    skip: skip,
    () async {
      final routes = await route(const CoreOptions(), urls);
      expect(routes, {
        '2.176.0.1': 'direct',
        'divar.ir': 'direct',
        'www.digikala.com': 'direct',
        'example.com': 'proxy',
        '8.8.8.8': 'proxy',
      });
    },
  );

  test('with the option off everything uses the proxy', skip: skip, () async {
    final routes = await route(const CoreOptions(bypassIran: false), urls);
    expect(routes.values.toSet(), {'proxy'});
    expect(routes, hasLength(urls.length));
  });
}
