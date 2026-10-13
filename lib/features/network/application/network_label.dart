import '../../../l10n/generated/app_localizations.dart';
import '../domain/network_identity.dart';

/// The network's name for people: the operator ("Irancell"), else its kind
/// ("Wi-Fi / home internet").
String networkLabelFor(
  AppLocalizations l10n,
  String languageCode,
  NetworkIdentity network,
) =>
    network.operatorLabel(languageCode) ??
    switch (network.kind) {
      NetworkKind.wifi => l10n.networkWifi,
      NetworkKind.cellular => l10n.networkMobile,
      NetworkKind.ethernet => l10n.networkEthernet,
      NetworkKind.desktop => l10n.networkThisComputer,
      NetworkKind.other => l10n.networkOther,
    };
