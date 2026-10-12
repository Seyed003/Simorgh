import 'package:flutter/material.dart';

import '../../../../core/utils/jalali.dart';

import '../../../../core/utils/context_ext.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/subscription.dart';

enum SubscriptionAction { update, test, speedTest, rename, delete }

/// Group header with name, quota usage and expiry for a subscription.
class SubscriptionHeader extends StatelessWidget {
  const SubscriptionHeader({
    super.key,
    required this.subscription,
    required this.count,
    required this.onAction,
  });

  final Subscription subscription;
  final int count;
  final ValueChanged<SubscriptionAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeCode;
    final info = subscription.info;
    final details = <String>[l10n.configCount(count)];
    double? progress;
    if (info != null && info.hasUsage) {
      details.add(
        l10n.trafficUsage(
          formatBytes(info.used, locale: locale),
          info.total > 0
              ? formatBytes(info.total, locale: locale)
              : l10n.unlimited,
        ),
      );
      if (info.total > 0) progress = (info.used / info.total).clamp(0.0, 1.0);
    }
    final expire = info?.expire;
    if (expire != null) {
      final days = expire.difference(DateTime.now()).inDays;
      details.add(
        days < 0
            ? l10n.expired
            : '${l10n.expiresOn(formatDate(expire.toLocal(), locale: locale))} · ${l10n.daysLeft(days)}',
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.rss_feed_rounded,
                size: 18,
                color: context.colors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subscription.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.updateSubscription,
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => onAction(SubscriptionAction.update),
              ),
              PopupMenuButton<SubscriptionAction>(
                onSelected: onAction,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: SubscriptionAction.test,
                    child: Text(l10n.testGroup),
                  ),
                  PopupMenuItem(
                    value: SubscriptionAction.speedTest,
                    child: Text(l10n.speedTestGroup),
                  ),
                  PopupMenuItem(
                    value: SubscriptionAction.rename,
                    child: Text(l10n.rename),
                  ),
                  PopupMenuItem(
                    value: SubscriptionAction.delete,
                    child: Text(l10n.delete),
                  ),
                ],
              ),
            ],
          ),
          Text(
            details.join(' · '),
            style: context.theme.textTheme.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                borderRadius: BorderRadius.circular(4),
                color: progress > 0.9 ? context.colors.error : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class GroupHeader extends StatelessWidget {
  const GroupHeader({super.key, required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 6),
      child: Row(
        children: [
          Icon(Icons.bookmark_rounded, size: 18, color: context.colors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: context.theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            context.l10n.configCount(count),
            style: context.theme.textTheme.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
