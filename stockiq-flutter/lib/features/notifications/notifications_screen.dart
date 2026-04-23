import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Notificações vindas do Firebase Messaging ficam salvas localmente
    final notifications = _mockNotifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Marcar todas lidas', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: notifications.isEmpty
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
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _NotificationCard(n: notifications[i]),
            ),
    );
  }

  static final _mockNotifications = [
    _Notif(
      title: 'Estoque crítico',
      body: 'Produto A-204 abaixo do mínimo (3 unid)',
      type: 'warning',
      time: 'Há 5 min',
      read: false,
    ),
    _Notif(
      title: 'Alerta da IA',
      body: 'Filial Santos com queda de 22% nas vendas esta semana.',
      type: 'danger',
      time: 'Há 1h',
      read: false,
    ),
    _Notif(
      title: 'Produto parado',
      body: 'Monitor 27" 4K LG sem movimento há 45 dias.',
      type: 'info',
      time: 'Ontem',
      read: true,
    ),
    _Notif(
      title: 'Entrada registrada',
      body: 'Notebook Dell XPS 15: +10 unidades na Matriz SP.',
      type: 'success',
      time: 'Ontem',
      read: true,
    ),
  ];
}

class _Notif {
  final String title, body, type, time;
  final bool read;
  const _Notif({required this.title, required this.body, required this.type, required this.time, required this.read});
}

class _NotificationCard extends StatelessWidget {
  final _Notif n;
  const _NotificationCard({required this.n});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (n.type) {
      'warning' => (AppTheme.warning, Icons.warning_amber_rounded),
      'danger'  => (AppTheme.danger,  Icons.error_outline),
      'success' => (AppTheme.success, Icons.check_circle_outline),
      _         => (AppTheme.info,    Icons.info_outline),
    };

    return Card(
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
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
            Text(n.time, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
