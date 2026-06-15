import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../lib/core/theme/app_theme.dart';

// ── Metric Card ───────────────────────────────────────────────────────────────

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final bool deltaPositive;
  final Color? valueColor;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.deltaPositive = true,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: valueColor,
                fontSize: 22,
              ),
            ),
            if (delta != null) ...[
              const SizedBox(height: 4),
              Text(
                delta!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: deltaPositive ? AppTheme.success : AppTheme.danger,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType type;

  const StatusBadge({super.key, required this.label, required this.type});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (type) {
      StatusType.success => (AppTheme.success.withOpacity(.12), AppTheme.success),
      StatusType.warning => (AppTheme.warning.withOpacity(.12), AppTheme.warning),
      StatusType.danger  => (AppTheme.danger.withOpacity(.12),  AppTheme.danger),
      StatusType.info    => (AppTheme.info.withOpacity(.12),    AppTheme.info),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

enum StatusType { success, warning, danger, info }

// ── Stock Level Bar ───────────────────────────────────────────────────────────

class StockLevelBar extends StatelessWidget {
  final int quantity;
  final int minQuantity;

  const StockLevelBar({super.key, required this.quantity, required this.minQuantity});

  @override
  Widget build(BuildContext context) {
    final maxDisplay = (minQuantity * 3).clamp(1, 9999);
    final ratio = (quantity / maxDisplay).clamp(0.0, 1.0);
    final color = ratio < 0.2
        ? AppTheme.danger
        : ratio < 0.5
            ? AppTheme.warning
            : AppTheme.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$quantity unid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            Text('mín $minQuantity', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 5,
            backgroundColor: color.withOpacity(.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

// ── Loading Shimmer ───────────────────────────────────────────────────────────

class ShimmerCard extends StatelessWidget {
  final double height;
  const ShimmerCard({super.key, this.height = 80});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor:  isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
      highlightColor: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 160,
                child: ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Error State ───────────────────────────────────────────────────────────────

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Tentar novamente')),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(action!, style: const TextStyle(fontSize: 13)),
          ),
      ],
    );
  }
}
