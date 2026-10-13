/// The kind of connection under the VPN.
enum NetworkKind { wifi, cellular, ethernet, desktop, other }

/// Which internet the device is on: a mobile operator, Wi-Fi, ... Settings
/// that get through the filtering are remembered per network.
class NetworkIdentity {
  const NetworkIdentity({required this.kind, this.operatorName, this.mccMnc});

  final NetworkKind kind;

  /// Mobile operator as the device names it, e.g. `IR-MCI`.
  final String? operatorName;

  /// Mobile country + network code, e.g. `43211` (MCI).
  final String? mccMnc;

  static const desktop = NetworkIdentity(kind: NetworkKind.desktop);

  factory NetworkIdentity.fromMap(Map<String, Object?> map) {
    String? text(String key) {
      final value = map[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    return NetworkIdentity(
      kind: NetworkKind.values.asNameMap()[map['kind']] ?? NetworkKind.other,
      operatorName: text('operator'),
      mccMnc: text('mccMnc'),
    );
  }

  /// Storage key: one per mobile operator, one for Wi-Fi, ...
  String get key => switch (kind) {
    NetworkKind.cellular => 'cellular:${mccMnc ?? operatorName ?? '?'}',
    _ => kind.name,
  };

  /// Iranian mobile operators by MCC+MNC.
  static const iranianOperators = {
    '43211': (fa: 'همراه اول', en: 'MCI (Hamrah-e Aval)'),
    '43235': (fa: 'ایرانسل', en: 'Irancell'),
    '43220': (fa: 'رایتل', en: 'RighTel'),
  };

  /// Operator name for display, `null` for networks without one.
  String? operatorLabel(String languageCode) {
    if (kind != NetworkKind.cellular) return null;
    final known = iranianOperators[mccMnc];
    if (known != null) return languageCode == 'fa' ? known.fa : known.en;
    return operatorName;
  }

  @override
  bool operator ==(Object other) =>
      other is NetworkIdentity && other.key == key;

  @override
  int get hashCode => key.hashCode;
}
