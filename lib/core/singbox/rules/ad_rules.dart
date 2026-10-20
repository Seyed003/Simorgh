/// Rule-set tag for the optional "block ads and trackers" option.
abstract final class AdRuleSets {
  static const ads = 'block-ads';
}

/// Domain suffixes of the big advertising and tracking networks. Kept to
/// domains that only serve ads or analytics, so ordinary sites and logins
/// keep working — this is a lightweight, built-in block, not a full ad-block
/// list. Folded into the config as an inline rule set.
const adDomainSuffixes = <String>[
  // Google advertising & analytics.
  'doubleclick.net',
  'googlesyndication.com',
  'googleadservices.com',
  'google-analytics.com',
  'googletagmanager.com',
  'googletagservices.com',
  'app-measurement.com',
  '2mdn.net',
  'adservice.google.com',
  // Ad exchanges / SSPs / DSPs.
  'adnxs.com',
  'rubiconproject.com',
  'pubmatic.com',
  'openx.net',
  'criteo.com',
  'criteo.net',
  'casalemedia.com',
  'adsrvr.org',
  'smartadserver.com',
  'adform.net',
  '3lift.com',
  'sharethrough.com',
  'bidswitch.net',
  'serving-sys.com',
  'moatads.com',
  'adsafeprotected.com',
  'amazon-adsystem.com',
  // Content-recommendation ad widgets.
  'taboola.com',
  'outbrain.com',
  'mgid.com',
  'revcontent.com',
  'zedo.com',
  // Analytics & trackers.
  'scorecardresearch.com',
  'quantserve.com',
  'bat.bing.com',
  // Mobile-ad SDKs.
  'applovin.com',
  'adcolony.com',
  'chartboost.com',
  'vungle.com',
  'inmobi.com',
  'unityads.unity3d.com',
];

/// An inline sing-box rule set matching the ad/tracker domains above.
Map<String, Object?> adRuleSet() => {
  'type': 'inline',
  'tag': AdRuleSets.ads,
  'rules': [
    {'domain_suffix': adDomainSuffixes},
  ],
};
