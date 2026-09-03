import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/notification_item.dart';
import '../services/notification_service.dart';

class NotificationsNotifier extends AsyncNotifier<List<NotificationItem>> {
  @override
  Future<List<NotificationItem>> build() => NotificationService.instance.getStored();

  Future<void> markRead(String id) async {
    await NotificationService.instance.markRead(id);
    state = AsyncData(await NotificationService.instance.getStored());
  }

  Future<void> markAllRead() async {
    await NotificationService.instance.markAllRead();
    state = AsyncData(await NotificationService.instance.getStored());
  }

  Future<void> refresh() async {
    state = AsyncData(await NotificationService.instance.getStored());
  }
}

final notificationsProvider = AsyncNotifierProvider<NotificationsNotifier, List<NotificationItem>>(
  NotificationsNotifier.new,
);
