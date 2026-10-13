import 'package:aghelan_ghiamat/core/theme/app_theme.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/logs/domain/core_log_line.dart';
import 'package:aghelan_ghiamat/features/logs/presentation/logs_page.dart';
import 'package:aghelan_ghiamat/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';

void main() {
  test('levels from libbox numbers and desktop text', () {
    expect(CoreLogLine.leveled(2, 'x').level, LogLevel.error);
    expect(CoreLogLine.leveled(99, 'x').level, LogLevel.trace);
    expect(
      CoreLogLine.parse('+0330 2026-10-12 21:00:00 WARN [1] dns: slow').level,
      LogLevel.warn,
    );
    expect(CoreLogLine.parse('plain').level, LogLevel.info);
    expect(CoreLogLine.parse('ERROR boom').isProblem, isTrue);
  });

  testWidgets('shows the core log and filters problems', (tester) async {
    final platform = FakeVpnPlatform();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [vpnPlatformProvider.overrideWithValue(platform)],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const LogsPage(),
        ),
      ),
    );
    expect(find.textContaining('No logs yet'), findsOneWidget);

    platform.logs
      ..add(const CoreLogLine('router: started'))
      ..add(
        const CoreLogLine('outbound/vless: dial failed', level: LogLevel.error),
      );
    await tester.pump();
    expect(find.text('router: started'), findsOneWidget);
    expect(find.text('outbound/vless: dial failed'), findsOneWidget);

    await tester.tap(find.byTooltip('Warnings and errors only'));
    await tester.pump();
    expect(find.text('router: started'), findsNothing);
    expect(find.text('outbound/vless: dial failed'), findsOneWidget);
  });
}
