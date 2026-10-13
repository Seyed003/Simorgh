/// A well-known DNS server the user can pick instead of typing one.
class DnsPreset {
  const DnsPreset(
    this.name,
    this.address, {
    this.blocksAds = false,
    this.domestic = false,
  });

  final String name;
  final String address;
  final bool blocksAds;

  /// Inside Iran: still answers when the international link is cut.
  final bool domestic;
}

/// Encrypted resolvers for lookups sent through the proxy.
const remoteDnsPresets = [
  DnsPreset('Cloudflare', 'https://1.1.1.1/dns-query'),
  DnsPreset('Google', 'https://8.8.8.8/dns-query'),
  DnsPreset('Quad9', 'https://9.9.9.9/dns-query'),
  DnsPreset('AdGuard', 'https://94.140.14.14/dns-query', blocksAds: true),
  DnsPreset('Cloudflare (DoT)', 'tls://1.1.1.1'),
];

/// Resolvers reached directly: Iranian sites and proxy server names. The
/// Iranian ones also lift sanctions-based blocks on developer sites.
const directDnsPresets = [
  DnsPreset('Cloudflare', '1.1.1.1'),
  DnsPreset('Google', '8.8.8.8'),
  DnsPreset('Shecan', '178.22.122.100', domestic: true),
  DnsPreset('Electro', '78.157.42.100', domestic: true),
  DnsPreset('Radar Game', '10.202.10.10', domestic: true),
  DnsPreset('local', 'local', domestic: true),
];

/// Whether the direct DNS [address] is one that works on the national
/// internet: the system's own resolver or an Iranian one.
bool isDomesticDns(String address) =>
    directDnsPresets.any((p) => p.domestic && p.address == address.trim());
