import '../../../core/singbox/builder/test_config_builder.dart';
import '../../../core/singbox/proxy_config.dart';
import '../../connection/data/vpn_platform.dart';
import '../../connection/domain/vpn_state.dart';

/// Why a server could not be tested at all.
enum CoreRejection {
  /// The core rejected this server's config.
  invalidConfig,

  /// The test core could not start.
  coreError,
}

typedef StartedTestCore = ({
  TestConfig? config,
  Map<String, CoreRejection> rejected,
});

/// Validates [proxies] as one test config and starts the test core with it.
///
/// One invalid server must not sink the whole run: sing-box names the
/// outbound it rejects, so that one is dropped and the rest validated again.
/// Returns the config the core runs (`null` if it could not start) and the
/// servers left out.
Future<StartedTestCore> startTestCore({
  required VpnPlatform platform,
  required Map<String, ProxyConfig> proxies,
  required TestConfig Function(Map<String, ProxyConfig> proxies) build,
}) async {
  final pending = Map.of(proxies);
  final rejected = <String, CoreRejection>{};

  StartedTestCore failAll() {
    for (final id in pending.keys) {
      rejected[id] = CoreRejection.coreError;
    }
    return (config: null, rejected: rejected);
  }

  while (pending.isNotEmpty) {
    final candidate = build(pending);
    final error = await platform.checkConfig(candidate.encode());
    if (error == null) {
      try {
        await platform.startTester(candidate.encode());
      } on VpnError {
        return failAll();
      }
      return (config: candidate, rejected: rejected);
    }
    final blamed = candidate.idBlamedBy(error);
    if (blamed == null) return failAll();
    pending.remove(blamed);
    rejected[blamed] = CoreRejection.invalidConfig;
  }
  return (config: null, rejected: rejected);
}
