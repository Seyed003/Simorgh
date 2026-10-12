import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/glass.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/utils/context_ext.dart';
import '../../connection/application/vpn_controller.dart';
import '../domain/core_log_line.dart';

/// The running core's log, newest at the bottom, to find out why a config
/// does not connect.
class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});

  static const maxLines = 1000;

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  final _lines = <CoreLogLine>[];
  final _scroll = ScrollController();
  StreamSubscription<CoreLogLine>? _subscription;
  bool _problemsOnly = false;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    unawaited(_subscription?.cancel());
    _subscription = ref.read(vpnPlatformProvider).coreLogs().listen((line) {
      if (!mounted) return;
      final atEnd =
          !_scroll.hasClients ||
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 48;
      setState(() {
        _lines.add(line);
        if (_lines.length > LogsPage.maxLines) _lines.removeAt(0);
      });
      if (atEnd) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A freshly started core has a new log to follow.
    ref.listen(vpnControllerProvider.select((s) => s.isConnected), (_, now) {
      if (now) _listen();
    });
    final l10n = context.l10n;
    final status = StatusColors.of(context);
    final shown = _problemsOnly
        ? _lines.where((l) => l.isProblem).toList()
        : _lines;
    final mono = context.theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Courier New', 'Vazirmatn'],
      height: 1.35,
    );

    return GlassScaffold(
      appBar: AppBar(
        title: Text(l10n.logs),
        actions: [
          IconButton(
            tooltip: l10n.logsProblemsOnly,
            isSelected: _problemsOnly,
            icon: const Icon(Icons.filter_alt_outlined),
            selectedIcon: const Icon(Icons.filter_alt_rounded),
            onPressed: () => setState(() => _problemsOnly = !_problemsOnly),
          ),
          IconButton(
            tooltip: l10n.copyAll,
            icon: const Icon(Icons.copy_all_rounded),
            onPressed: shown.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text: shown.map((l) => l.message).join('\n'),
                      ),
                    );
                    if (context.mounted) context.showSnack(l10n.copied);
                  },
          ),
        ],
      ),
      body: shown.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.logsEmpty,
                  textAlign: TextAlign.center,
                  style: context.theme.textTheme.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Glass(
                blur: false,
                radius: 22,
                child: SelectionArea(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final line = shown[i];
                      final color = switch (line.level) {
                        LogLevel.panic ||
                        LogLevel.fatal ||
                        LogLevel.error => status.error,
                        LogLevel.warn => status.connecting,
                        LogLevel.debug ||
                        LogLevel.trace => context.colors.onSurfaceVariant,
                        LogLevel.info => context.colors.onSurface,
                      };
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          line.message,
                          textDirection: TextDirection.ltr,
                          style: mono?.copyWith(color: color),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }
}
