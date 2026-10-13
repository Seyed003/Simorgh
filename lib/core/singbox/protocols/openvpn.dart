import '../proxy_config.dart';

/// Whether [text] is an OpenVPN client profile (the contents of a `.ovpn`
/// file) rather than share links or JSON.
bool isOpenVpnProfile(String text) =>
    RegExp(r'^[ \t]*(--)?remote[ \t]+\S', multiLine: true).hasMatch(text) &&
    RegExp(
      r'^[ \t]*(--)?(client|tls-client|pull|dev[ \t]|secret\b|<ca>)',
      multiLine: true,
    ).hasMatch(text);

/// Converts an OpenVPN client profile into a sing-box `openvpn-client`
/// endpoint. Certificates and keys must be inside the profile (`<ca>`,
/// `<cert>`, `<key>`, `<tls-crypt>` …), as in the files VPN sellers and
/// panels hand out; a profile asking for a username and password without
/// carrying them gets empty ones, to be filled in by the user
/// ([ProxyConfig.needsLogin]).
///
/// [name] (usually the file name) is used when the profile names nothing.
ProxyConfig parseOpenVpn(String text, {String? name}) {
  final profile = _Profile.parse(text);
  final out = <String, Object?>{'type': 'openvpn-client'};
  final tls = <String, Object?>{};

  // --- Servers -------------------------------------------------------------
  final defaultNetwork = _network(profile.last('proto')?.firstOrNull) ?? 'udp';
  final defaultPort =
      _port(profile.last('port')?.firstOrNull) ??
      _port(profile.last('rport')?.firstOrNull) ??
      1194;
  final servers = <Map<String, Object?>>[];
  void addRemotes(_Profile scope, String network, int port) {
    for (final args in scope.all('remote')) {
      if (args.isEmpty) continue;
      servers.add({
        'server': args[0],
        'server_port': _port(args.elementAtOrNull(1)) ?? port,
        'network': _network(args.elementAtOrNull(2)) ?? network,
      });
    }
  }

  addRemotes(profile, defaultNetwork, defaultPort);
  for (final connection in profile.connections) {
    addRemotes(
      connection,
      _network(connection.last('proto')?.firstOrNull) ?? defaultNetwork,
      _port(connection.last('port')?.firstOrNull) ?? defaultPort,
    );
  }
  if (servers.isEmpty) {
    throw const LinkParseException('OpenVPN profile has no "remote" server');
  }
  if (servers.length == 1) {
    out
      ..['server'] = servers.single['server']
      ..['server_port'] = servers.single['server_port']
      ..['network'] = servers.single['network'];
  } else {
    out
      ..['servers'] = servers
      ..['network'] = defaultNetwork;
    if (profile.has('remote-random')) out['remote_random'] = true;
  }
  final udpOnly = servers.every((s) => s['network'] == 'udp');

  // --- Things this client cannot do ---------------------------------------
  for (final args in [...profile.all('dev'), ...profile.all('dev-type')]) {
    if (args.firstOrNull?.toLowerCase().startsWith('tap') ?? false) {
      throw const UnsupportedLinkException('OpenVPN TAP (bridged) mode');
    }
  }
  const unsupported = {
    'pkcs12': 'PKCS#12 certificate bundles',
    'cryptoapicert': 'Windows certificate store',
    'management-external-key': 'external private keys',
    'management-external-cert': 'external certificates',
    'http-proxy': 'OpenVPN through an HTTP proxy',
    'socks-proxy': 'OpenVPN through a SOCKS proxy',
    'static-challenge': 'one-time-password logins',
    'askpass': 'password-protected private keys',
    'tls-server': 'server profiles',
    'server': 'server profiles',
  };
  for (final MapEntry(:key, :value) in unsupported.entries) {
    if (profile.has(key)) throw UnsupportedLinkException(value);
  }

  // --- Static key mode (no TLS) -------------------------------------------
  final secret = profile.last('secret');
  if (secret != null) {
    out['mode'] = 'static_key';
    out['static_key'] = profile.inline('secret', 'secret');
    final direction = _direction(
      secret.length > 1 ? secret[1] : profile.last('key-direction')?.first,
    );
    if (direction != null) out['key_direction'] = direction;
    final ifconfig = profile.last('ifconfig');
    if (ifconfig == null || ifconfig.length < 2) {
      throw const LinkParseException('static-key profile without "ifconfig"');
    }
    out['address'] = ['${ifconfig[0]}/32'];
    out['peer_address'] = ifconfig[1];
    final cipher = profile.last('cipher')?.firstOrNull;
    if (cipher != null) out['cipher'] = cipher.toUpperCase();
  } else {
    // --- TLS ---------------------------------------------------------------
    final ca = profile.blocks['ca'];
    final fingerprints = [
      for (final args in profile.all('peer-fingerprint')) ...args,
      ...?profile.blocks['peer-fingerprint']?.split(RegExp(r'\s+')),
    ].map(_fingerprint).nonNulls.toList();
    if (ca != null) {
      tls['certificate'] = _pem(ca, 'ca');
    } else if (fingerprints.isNotEmpty) {
      tls['peer_fingerprint'] = fingerprints;
    } else if (profile.has('ca')) {
      throw const LinkParseException(
        'the CA certificate is a separate file; use a profile with <ca> inside',
      );
    } else {
      throw const LinkParseException('OpenVPN profile has no CA certificate');
    }
    if (ca != null && fingerprints.isNotEmpty) {
      tls['peer_fingerprint'] = fingerprints;
    }

    final cert = profile.blocks['cert'];
    final key = profile.blocks['key'];
    if (cert != null || key != null || profile.has('cert')) {
      if (cert == null || key == null) {
        throw const LinkParseException(
          'the client certificate or key is a separate file',
        );
      }
      if (key.contains('ENCRYPTED')) {
        throw const UnsupportedLinkException('password-protected private keys');
      }
      tls['client_certificate'] = _pem(cert, 'cert');
      tls['client_key'] = _pem(key, 'key');
    }

    final x509 = profile.last('verify-x509-name');
    if (x509 != null && x509.isNotEmpty) {
      tls['server_name'] = x509[0];
      tls['server_name_type'] = switch (x509.elementAtOrNull(1)) {
        'name' => 'name',
        'name-prefix' => 'name-prefix',
        _ => 'subject',
      };
    }
    final eku = profile.last('remote-cert-eku')?.firstOrNull;
    if (eku != null) {
      tls['remote_certificate_eku'] = eku;
    } else if (profile.last('remote-cert-tls')?.firstOrNull case final p?) {
      tls['remote_certificate_tls'] = p;
    }
    final ku = profile.last('remote-cert-ku');
    if (ku != null && ku.isNotEmpty) tls['remote_certificate_ku'] = ku;
    if (profile.last('ns-cert-type')?.firstOrNull case final t?) {
      tls['ns_certificate_type'] = t;
    }
    if (profile.last('tls-version-min')?.firstOrNull case final v?) {
      tls['version_min'] = v;
    }
    if (profile.last('tls-version-max')?.firstOrNull case final v?) {
      tls['version_max'] = v;
    }
    if (profile.last('tls-cipher')?.firstOrNull case final c?) {
      tls['cipher'] = c;
    }
    if (profile.last('tls-groups')?.firstOrNull case final g?) {
      tls['groups'] = g;
    }
    if (profile.last('tls-cert-profile')?.firstOrNull case final p?) {
      tls['certificate_profile'] = p;
    }

    // tls-auth / tls-crypt / tls-crypt-v2 wrap the control channel.
    for (final (directive, type) in const [
      ('tls-crypt-v2', 'tls_crypt_v2'),
      ('tls-crypt', 'tls_crypt'),
      ('tls-auth', 'tls_auth'),
    ]) {
      final args = profile.last(directive);
      if (args == null && !profile.blocks.containsKey(directive)) continue;
      final wrap = <String, Object?>{
        'type': type,
        'key': profile.inline(directive, directive),
      };
      if (type == 'tls_auth') {
        final direction = _direction(
          args != null && args.length > 1
              ? args[1]
              : profile.last('key-direction')?.firstOrNull,
        );
        if (direction != null) wrap['direction'] = direction;
      }
      tls['control_wrap'] = wrap;
      break;
    }
    out['tls'] = tls;

    // Data channel ciphers: `cipher` alone is what OpenVPN 2.3 servers use,
    // newer ones negotiate from `data-ciphers`.
    final cipher = profile.last('cipher')?.firstOrNull?.toUpperCase();
    final listed = (profile.last('data-ciphers') ?? profile.last('ncp-ciphers'))
        ?.firstOrNull
        ?.split(':')
        .where((c) => c.isNotEmpty)
        .map((c) => c.toUpperCase())
        .toList();
    final ciphers =
        listed ??
        (cipher != null
            ? ['AES-256-GCM', 'AES-128-GCM', 'CHACHA20-POLY1305']
            : null);
    if (ciphers != null) {
      if (cipher != null && !ciphers.contains(cipher)) ciphers.add(cipher);
      out['data_ciphers'] = ciphers;
    }
    final fallback =
        profile.last('data-ciphers-fallback')?.firstOrNull?.toUpperCase() ??
        cipher;
    if (fallback != null) out['data_ciphers_fallback'] = fallback;

    // Username and password.
    if (profile.has('auth-user-pass') ||
        profile.blocks.containsKey('auth-user-pass')) {
      final lines = (profile.blocks['auth-user-pass'] ?? '')
          .split(RegExp(r'\r?\n'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      out['username'] = lines.elementAtOrNull(0) ?? '';
      out['password'] = lines.elementAtOrNull(1) ?? '';
    }
    out['auth_retry'] = 'none';
  }

  // --- Data channel and timers --------------------------------------------
  if (profile.last('auth')?.firstOrNull case final digest?) {
    out['auth'] = digest.toUpperCase();
  }
  _compression(profile, out);
  if (profile.has('route-nopull')) out['route_no_pull'] = true;
  final filters = [
    for (final args in profile.all('pull-filter'))
      if (args.length >= 2 &&
          const {'accept', 'ignore', 'reject'}.contains(args[0]))
        {'action': args[0], 'text': args[1]},
  ];
  if (filters.isNotEmpty) out['pull_filters'] = filters;
  if (profile.last('topology')?.firstOrNull case final t?) {
    out['topology'] = t;
  }

  final keepalive = profile.last('keepalive');
  final ping =
      _int(profile.last('ping')?.firstOrNull) ?? _int(keepalive?.firstOrNull);
  if (ping != null && ping > 0) out['ping_interval'] = '${ping}s';
  final pingRestart =
      _int(profile.last('ping-restart')?.firstOrNull) ??
      _int(keepalive?.elementAtOrNull(1));
  if (pingRestart != null) {
    if (pingRestart > 0) {
      out['ping_restart'] = '${pingRestart}s';
    } else {
      out['ping_restart_disabled'] = true;
    }
  }
  final reneg = _int(profile.last('reneg-sec')?.firstOrNull);
  if (reneg != null) {
    if (reneg > 0) {
      out['renegotiate_interval'] = '${reneg}s';
    } else {
      out['renegotiate_disabled'] = true;
    }
  }
  if (_int(profile.last('reneg-bytes')?.firstOrNull) case final b?) {
    out['renegotiate_bytes'] = b;
  }
  if (_int(profile.last('reneg-pkts')?.firstOrNull) case final p?) {
    out['renegotiate_packets'] = p;
  }
  if (_int(profile.last('hand-window')?.firstOrNull) case final s? when s > 0) {
    out['handshake_window'] = '${s}s';
  }
  if (_int(profile.last('tls-timeout')?.firstOrNull) case final s? when s > 0) {
    out['tls_timeout'] = '${s}s';
  }

  if (_int(profile.last('tun-mtu')?.firstOrNull) case final mtu?
      when mtu >= 576) {
    out['mtu'] = mtu;
  }
  final mssfix = profile.last('mssfix');
  if (mssfix != null && mssfix.isNotEmpty) {
    final size = _int(mssfix[0]);
    if (size == 0) {
      out['mss_fix_disabled'] = true;
    } else if (size != null) {
      out['mss_fix'] = size;
      final mode = mssfix.elementAtOrNull(1);
      if (mode == 'mtu' || mode == 'fixed') out['mss_fix_mode'] = mode;
    }
  }
  if (udpOnly) {
    if (_int(profile.last('fragment')?.firstOrNull) case final f?
        when f >= 68) {
      out['fragment'] = f;
    }
    final exit = profile.last('explicit-exit-notify');
    if (exit != null) out['explicit_exit_notify'] = _int(exit.firstOrNull) ?? 1;
  }
  final replay = profile.last('replay-window');
  if (replay != null && replay.isNotEmpty) {
    if (_int(replay[0]) case final n? when n > 0) out['replay_window'] = n;
    if (_int(replay.elementAtOrNull(1)) case final s? when s > 0) {
      out['replay_window_time'] = '${s}s';
    }
  }

  final first = servers.first;
  final friendly = profile
      .all('setenv')
      .where((a) => a.length >= 2 && a[0] == 'FRIENDLY_NAME')
      .map((a) => a[1])
      .firstOrNull;
  final label = [
    friendly,
    name,
  ].map((n) => n?.trim()).where((n) => n != null && n.isNotEmpty).firstOrNull;
  return ProxyConfig(
    protocol: ProxyProtocol.openvpn,
    name: label ?? 'OpenVPN ${first['server']}',
    server: first['server']! as String,
    port: first['server_port']! as int,
    outbound: out,
  );
}

void _compression(_Profile profile, Map<String, Object?> out) {
  var compresses = false;
  final lzo = profile.last('comp-lzo');
  if (lzo != null) {
    final mode = (lzo.firstOrNull ?? 'adaptive').toLowerCase();
    out['compression_lzo'] = mode;
    compresses = const {'yes', 'adaptive', 'asym'}.contains(mode);
  }
  final compress = profile.last('compress');
  if (compress != null) {
    final algorithm = (compress.firstOrNull ?? 'stub').toLowerCase();
    switch (algorithm) {
      case 'lzo':
        out['compression_lzo'] = 'yes';
        compresses = true;
      case 'lz4' || 'lz4-v2':
        out['compression'] = algorithm;
        compresses = true;
      case 'stub' || 'stub-v2' || 'none' || 'no' || 'disabled' || 'off':
        out['compression'] = algorithm;
      default:
        // `compress migrate` and future algorithms: leave it to the server.
        break;
    }
  }
  final allow = profile.last('allow-compression')?.firstOrNull?.toLowerCase();
  if (compresses) {
    out['allow_compression'] = allow == 'yes' ? 'yes' : 'asym';
  } else if (allow == 'asym' || allow == 'yes' || allow == 'no') {
    out['allow_compression'] = allow;
  }
}

/// `0`/`1` (or `server`/`client`) of `key-direction` and friends.
String? _direction(String? value) => switch (value?.toLowerCase()) {
  '0' || 'server' => 'server',
  '1' || 'client' => 'client',
  _ => null,
};

String? _network(String? proto) {
  if (proto == null) return null;
  final p = proto.toLowerCase();
  if (p == 'tcp-server') {
    throw const UnsupportedLinkException('server profiles');
  }
  if (p.startsWith('tcp')) return 'tcp';
  if (p.startsWith('udp')) return 'udp';
  return null;
}

int? _port(String? value) {
  final port = int.tryParse(value ?? '');
  return port != null && port > 0 && port < 65536 ? port : null;
}

int? _int(String? value) => int.tryParse(value ?? '');

/// SHA-256 fingerprint as sing-box wants it: 64 lowercase hex digits.
String? _fingerprint(String value) {
  final hex = value.replaceAll(':', '').toLowerCase();
  return RegExp(r'^[0-9a-f]{64}$').hasMatch(hex) ? hex : null;
}

/// Only the PEM blocks of [text]: `<cert>` often starts with an OpenSSL
/// dump of the certificate.
String _pem(String text, String block) {
  final pems = RegExp(r'-----BEGIN [^-]+-----[\s\S]*?-----END [^-]+-----')
      .allMatches(text)
      .map((m) => m[0]!)
      .toList();
  if (pems.isEmpty) {
    throw LinkParseException('<$block> holds no PEM data');
  }
  return pems.join('\n');
}

/// The directives and inline `<blocks>` of a profile.
class _Profile {
  final _directives = <String, List<List<String>>>{};
  final blocks = <String, String>{};
  final connections = <_Profile>[];

  static _Profile parse(String text) {
    final profile = _Profile();
    final lines = text.replaceFirst('﻿', '').split(RegExp(r'\r?\n'));
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final open = RegExp(r'^<([\w-]+)>$').firstMatch(line);
      if (open != null) {
        final tag = open[1]!.toLowerCase();
        final body = <String>[];
        for (i++; i < lines.length; i++) {
          if (lines[i].trim().toLowerCase() == '</$tag>') break;
          body.add(lines[i]);
        }
        if (tag == 'connection') {
          profile.connections.add(_Profile.parse(body.join('\n')));
        } else {
          profile.blocks[tag] = body.join('\n').trim();
        }
        continue;
      }
      final words = _split(line);
      if (words.isEmpty) continue;
      var name = words.first.toLowerCase();
      if (name.startsWith('--')) name = name.substring(2);
      profile._directives.putIfAbsent(name, () => []).add(words.sublist(1));
    }
    return profile;
  }

  bool has(String name) => _directives.containsKey(name);

  List<List<String>> all(String name) => _directives[name] ?? const [];

  List<String>? last(String name) => _directives[name]?.last;

  /// The inline `<block>` for a directive that names a key file.
  String inline(String directive, String block) {
    final content = blocks[block];
    if (content != null && content.isNotEmpty) return content;
    throw LinkParseException(
      'the $directive key is a separate file; use a profile with <$block> inside',
    );
  }

  /// OpenVPN's tokenizer: whitespace separated, `"…"`/`'…'` quoting,
  /// backslash escapes in double quotes, `#`/`;` starting a comment.
  static List<String> _split(String line) {
    final words = <String>[];
    final current = StringBuffer();
    var inWord = false;
    String? quote;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (quote != null) {
        if (c == quote) {
          quote = null;
        } else if (c == r'\' && quote == '"' && i + 1 < line.length) {
          current.write(line[++i]);
        } else {
          current.write(c);
        }
        continue;
      }
      if (c == ' ' || c == '\t') {
        if (inWord) {
          words.add(current.toString());
          current.clear();
          inWord = false;
        }
        continue;
      }
      if (!inWord && (c == '#' || c == ';')) break;
      inWord = true;
      if (c == '"' || c == "'") {
        quote = c;
      } else {
        current.write(c);
      }
    }
    if (inWord) words.add(current.toString());
    return words;
  }
}
