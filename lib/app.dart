import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/profiles/presentation/subscription_auto_update.dart';
import 'features/settings/application/settings_controller.dart';
import 'features/shell/app_shell.dart';
import 'l10n/generated/app_localizations.dart';

class AghelanApp extends ConsumerWidget {
  const AghelanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      // Persian is right-to-left; GlobalWidgetsLocalizations flips the
      // ambient Directionality automatically for the `fa` locale.
      locale: settings.language.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SubscriptionAutoUpdate(child: AppShell()),
    );
  }
}
