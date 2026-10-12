import 'package:aghelan_ghiamat/features/profiles/application/incoming_import.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/singbox/fixtures.dart';

void main() {
  test('config links and shared text', () {
    final single = IncomingImport.parse(vlessReality);
    expect(single, isA<IncomingConfigs>());
    expect((single! as IncomingConfigs).count, 1);
    final shared = IncomingImport.parse('Try these:\n$trojanBare\n$hy2\n');
    expect((shared! as IncomingConfigs).count, 2);
    expect(IncomingImport.parse('hello there'), isNull);
    expect(IncomingImport.parse('   '), isNull);
  });

  test('subscription links in the formats panels use', () {
    void sub(String link, String url, [String? name]) {
      final parsed = IncomingImport.parse(link);
      expect(parsed, isA<IncomingSubscription>(), reason: link);
      final subscription = parsed! as IncomingSubscription;
      expect(subscription.url, url, reason: link);
      expect(subscription.name, name, reason: link);
    }

    const url = 'https://panel.example/sub/abc?x=1';
    final encoded = Uri.encodeComponent(url);
    sub(url, url);
    sub('aghelan://import?url=$encoded&name=My%20VPN', url, 'My VPN');
    sub('sing-box://import-remote-profile?url=$encoded#Panel', url, 'Panel');
    sub('v2rayng://install-sub?url=$encoded&name=P', url, 'P');
    sub('hiddify://import/$url#H', url, 'H');
    expect(
      (IncomingImport.parse(url)! as IncomingSubscription).host,
      'panel.example',
    );
  });

  test('config links wrapped in import links; junk is ignored', () {
    final wrapped = IncomingImport.parse(
      'v2rayng://install-config?url=${Uri.encodeComponent(trojanBare)}',
    );
    expect(wrapped, isA<IncomingConfigs>());
    expect(
      IncomingImport.parse('aghelan://add?config=${Uri.encodeComponent(hy2)}'),
      isA<IncomingConfigs>(),
    );
    expect(IncomingImport.parse('aghelan://import?url=ftp://x'), isNull);
    expect(IncomingImport.parse('sing-box://other?url=https://a.b'), isNull);
  });
}
