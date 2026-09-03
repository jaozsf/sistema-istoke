import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/notifications_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/animations.dart';
import '../../core/utils/responsive.dart';
import '../../shared/models/notification_item.dart';
import '../../shared/widgets/app_widgets.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          TextButton(
            onPressed: notifications.valueOrNull?.any((n) => !n.read) ?? false
                ? () => ref.read(notificationsProvider.notifier).markAllRead()
                : null,
            child: const Text('Marcar todas lidas', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: notifications.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ShimmerCard(height: 76),
            SizedBox(height: 8),
            ShimmerCard(height: 76),
            SizedBox(height: 8),
            ShimmerCard(height: 76),
          ],
        ),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: () => ref.read(notificationsProvider.notifier).refresh(),
            child: const Text('Erro ao carregar. Tentar novamente'),
          ),
        ),
        data: (items) => items.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none, size: 56, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('Nenhuma notificação'),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
                child: PageContainer(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _NotificationCard(n: items[i]).entrance(index: i),
                  ),
                ),
              ),
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  final NotificationItem n;
  const _NotificationCard({required this.n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (color, icon) = switch (n.type) {
      'warning' => (AppTheme.warning, Icons.warning_amber_rounded),
      'danger'  => (AppTheme.danger,  Icons.error_outline),
      'success' => (AppTheme.success, Icons.check_circle_outline),
      _         => (AppTheme.info,    Icons.info_outline),
    };

    final iconSize = context.isWide ? 48.0 : 40.0;
    return Card(
      child: ListTile(
        onTap: () {
          if (!n.read) ref.read(notificationsProvider.notifier).markRead(n.id);
          if (n.route != null) context.push(n.route!);
        },
        leading: Container(
          width: iconSize, height: iconSize,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: iconSize * 0.5),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                n.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: n.read ? FontWeight.w400 : FontWeight.w600,
                ),
              ),
            ),
            if (!n.read)
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n.body, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(_relativeTime(n.receivedAt), style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

/// "Há 5 min" / "Há 2h" / "Ontem" / "12/08" -- sem depender de pacote de
/// data extra só pra isso.
String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1)  return 'Agora';
  if (diff.inMinutes < 60) return 'Há ${diff.inMinutes} min';
  if (diff.inHours < 24)   return 'Há ${diff.inHours}h';
  if (diff.inDays == 1)    return 'Ontem';
  if (diff.inDays < 7)     return 'Há ${diff.inDays} dias';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
}
