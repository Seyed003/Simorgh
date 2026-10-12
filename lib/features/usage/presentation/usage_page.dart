import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/glass.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/jalali.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../application/usage_controller.dart';
import '../domain/usage.dart';

const _chartDays = 14;
const _tableDays = 30;

/// Data used through the tunnel: headline totals, the last two weeks as a
/// column chart (tap a day for its split) and a table of the last month.
class UsagePage extends ConsumerStatefulWidget {
  const UsagePage({super.key, this.today});

  /// Fixed "today" for tests and screenshots.
  final DateTime? today;

  @override
  ConsumerState<UsagePage> createState() => _UsagePageState();
}

class _UsagePageState extends ConsumerState<UsagePage> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeCode;
    final usage = ref.watch(usageProvider);
    final today = UsageState.dayOf(widget.today ?? DateTime.now());
    final chartDays = [
      for (var i = _chartDays - 1; i >= 0; i--)
        today.subtract(Duration(days: i)),
    ];
    final tableDays = [
      for (var i = 0; i < _tableDays; i++) today.subtract(Duration(days: i)),
    ].where((d) => usage.on(d).total > 0).toList();

    return ListView(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      children: [
        LargeTitle(
          title: l10n.usage,
          actions: [
            GlassMenuButton<void>(
              tooltip: l10n.usageReset,
              icon: Icons.more_horiz_rounded,
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: () async {
                    final ok = await confirmDialog(
                      context,
                      title: l10n.usageReset,
                      message: l10n.usageResetConfirm,
                      confirmLabel: l10n.delete,
                      destructive: true,
                    );
                    if (ok) await ref.read(usageProvider.notifier).reset();
                  },
                  child: Text(l10n.usageReset),
                ),
              ],
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  for (final (label, total) in [
                    (l10n.usageToday, usage.on(today)),
                    (l10n.usageWeek, usage.lastDays(7, today)),
                    (l10n.usageMonth, usage.lastDays(30, today)),
                  ])
                    Expanded(
                      child: _StatTile(label: label, usage: total),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Glass(
                blur: false,
                radius: 26,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.usageChartTitle,
                        style: context.theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      _SelectionLine(
                        day: _selected == null ? null : chartDays[_selected!],
                        usage: _selected == null
                            ? null
                            : usage.on(chartDays[_selected!]),
                      ),
                      const SizedBox(height: 8),
                      _UsageChart(
                        days: chartDays,
                        values: [for (final d in chartDays) usage.on(d).total],
                        selected: _selected,
                        onSelect: (i) => setState(
                          () => _selected = _selected == i ? null : i,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
                child: Text(
                  l10n.usageDaily,
                  style: context.theme.textTheme.titleSmall,
                ),
              ),
              Glass(
                blur: false,
                radius: 26,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: tableDays.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          l10n.usageEmpty,
                          textAlign: TextAlign.center,
                          style: context.theme.textTheme.bodyMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          _TableRow(
                            label: '',
                            cells: (
                              l10n.download,
                              l10n.upload,
                              l10n.totalTraffic,
                            ),
                            header: true,
                          ),
                          for (final day in tableDays)
                            _TableRow(
                              label: formatDate(day, locale: locale),
                              cells: (
                                formatBytes(usage.on(day).down, locale: locale),
                                formatBytes(usage.on(day).up, locale: locale),
                                formatBytes(
                                  usage.on(day).total,
                                  locale: locale,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.usage});

  final String label;
  final DayUsage usage;

  @override
  Widget build(BuildContext context) {
    final locale = context.localeCode;
    final muted = context.theme.textTheme.bodySmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Glass(
        blur: false,
        radius: 22,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: context.theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                formatBytes(usage.total, locale: locale),
                textDirection: TextDirection.ltr,
                style: context.theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: _UpDown(usage: usage, style: muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// What a tooltip would say, kept in place so the chart does not jump.
class _SelectionLine extends StatelessWidget {
  const _SelectionLine({required this.day, required this.usage});

  final DateTime? day;
  final DayUsage? usage;

  @override
  Widget build(BuildContext context) {
    final locale = context.localeCode;
    final style = context.theme.textTheme.bodySmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    final usage = this.usage;
    if (day == null || usage == null) {
      return Text(context.l10n.usageTapHint, style: style);
    }
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '${formatDate(day!, locale: locale)}:',
          style: style?.copyWith(color: context.colors.onSurface),
        ),
        Text(
          formatBytes(usage.total, locale: locale),
          textDirection: TextDirection.ltr,
          style: style?.copyWith(
            color: context.colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        _UpDown(usage: usage, style: style),
      ],
    );
  }
}

/// Download and upload with arrow icons, digits kept left-to-right.
class _UpDown extends StatelessWidget {
  const _UpDown({required this.usage, this.style});

  final DayUsage usage;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final locale = context.localeCode;
    final iconSize = (style?.fontSize ?? 12) + 1;
    final color = style?.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.arrow_downward_rounded, size: iconSize, color: color),
        Text(
          formatBytes(usage.down, locale: locale),
          textDirection: TextDirection.ltr,
          style: style,
        ),
        const SizedBox(width: 8),
        Icon(Icons.arrow_upward_rounded, size: iconSize, color: color),
        Text(
          formatBytes(usage.up, locale: locale),
          textDirection: TextDirection.ltr,
          style: style,
        ),
      ],
    );
  }
}

/// Single-series column chart: 1px gridline at the top value and the
/// baseline, columns <= 24px with 4px rounded tops, the whole day slot is
/// the tap target.
class _UsageChart extends StatelessWidget {
  const _UsageChart({
    required this.days,
    required this.values,
    required this.selected,
    required this.onSelect,
  });

  final List<DateTime> days;
  final List<int> values;
  final int? selected;
  final ValueChanged<int> onSelect;

  static const _plotHeight = 140.0;

  @override
  Widget build(BuildContext context) {
    final locale = context.localeCode;
    final grid = context.colors.outlineVariant;
    final axisStyle = context.theme.textTheme.labelSmall?.copyWith(
      color: context.colors.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final top = _niceCeiling(values.fold<int>(0, max));
    final barColor = context.colors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            formatBytes(top, locale: locale),
            textDirection: TextDirection.ltr,
            style: axisStyle,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: _plotHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: grid),
                bottom: BorderSide(color: grid),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (i, value) in values.indexed)
                  Expanded(
                    child: Semantics(
                      button: true,
                      label:
                          '${formatDate(days[i], locale: locale)}, '
                          '${formatBytes(value, locale: locale)}',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelect(i),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final height = top == 0
                                ? 0.0
                                : _plotHeight * value / top;
                            return Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: min(24, constraints.maxWidth - 2),
                                height: value > 0 ? max(height, 2) : 0,
                                decoration: BoxDecoration(
                                  color: selected == null || selected == i
                                      ? barColor
                                      : barColor.withValues(alpha: 0.45),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final (i, day) in days.indexed)
              Expanded(
                child: Text(
                  // Every other day, always the last one.
                  i.isEven == (days.length - 1).isEven
                      ? formatDayOfMonth(day, locale: locale)
                      : '',
                  textAlign: TextAlign.center,
                  style: axisStyle?.copyWith(
                    fontWeight: selected == i ? FontWeight.w700 : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Rounds the axis top up to 1, 2 or 5 × 10^n of the unit the label is
  /// shown in (KB, MB, GB are powers of 1024), so the label reads cleanly.
  static int _niceCeiling(int value) {
    if (value <= 0) return 0;
    var unit = 1;
    while (unit * 1024 <= value) {
      unit *= 1024;
    }
    final scaled = value / unit;
    var step = 1;
    while (step * 10 <= scaled) {
      step *= 10;
    }
    for (final m in [1, 2, 5, 10]) {
      if (step * m >= scaled) return step * m * unit;
    }
    return step * 10 * unit;
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.label,
    required this.cells,
    this.header = false,
  });

  final String label;
  final (String down, String up, String total) cells;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final base = header
        ? context.theme.textTheme.labelMedium
        : context.theme.textTheme.bodyMedium;
    final style = base?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: header ? context.colors.onSurfaceVariant : null,
    );
    final muted = style?.copyWith(color: context.colors.onSurfaceVariant);
    // Headers and left-to-right numbers line up on the same side.
    Widget cell(String text, TextStyle? style) => Expanded(
      flex: 2,
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Text(
          text,
          textDirection: header ? null : TextDirection.ltr,
          style: style,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label, style: style)),
          cell(cells.$1, muted),
          cell(cells.$2, muted),
          cell(
            cells.$3,
            header ? style : style?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
