import 'iran_ip_ranges.g.dart';

/// Rule-set tags used by the "Iranian sites without VPN" option.
abstract final class IranRuleSets {
  static const domains = 'iran-domains';
  static const ips = 'iran-ips';
}

/// Domains that go direct and are resolved by the direct DNS server. `ir`
/// covers every `.ir` site; the rest are well-known Iranian services on
/// other TLDs. Anything hosted on an Iranian IP is caught by
/// [iranIpv4Ranges]/[iranIpv6Ranges] anyway, so this list only needs the
/// big names (it saves a DNS round trip through the tunnel for them).
const iranDomainSuffixes = <String>[
  'ir',
  'aparat.com',
  'arvancloud.com',
  'bale.ai',
  'blogfa.com',
  'digikala.com',
  'eitaa.com',
  'filimo.com',
  'ninisite.com',
  'sheypoor.com',
  'tebyan.net',
  'telewebion.com',
  'tgju.org',
  'torob.com',
  'varzesh3.com',
];

/// Inline sing-box rule sets with Iranian domains and IP ranges.
List<Map<String, Object?>> iranRuleSets({required bool ipv6}) => [
  {
    'type': 'inline',
    'tag': IranRuleSets.domains,
    'rules': [
      {'domain_suffix': iranDomainSuffixes},
    ],
  },
  {
    'type': 'inline',
    'tag': IranRuleSets.ips,
    'rules': [
      {
        'ip_cidr': [...iranIpv4Ranges, if (ipv6) ...iranIpv6Ranges],
      },
    ],
  },
];
