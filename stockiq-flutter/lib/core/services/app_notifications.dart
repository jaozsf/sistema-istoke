import 'package:flutter/foundation.dart' show kIsWeb;
import 'notification_service.dart';
import 'web_notifications.dart';

/// Ponto único de notificação — escolhe a implementação certa por
/// plataforma (Web Notification API vs flutter_local_notifications).
class AppNotifications {
  AppNotifications._();

  static Future<bool> requestPermission() async {
    if (kIsWeb) return requestWebNotificationPermission();
    try {
      await NotificationService.instance.initialize();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> notify(String title, String body) async {
    if (kIsWeb) {
      showWebNotification(title, body);
    } else {
      await NotificationService.instance.showAlert(title, body);
    }
  }
}
