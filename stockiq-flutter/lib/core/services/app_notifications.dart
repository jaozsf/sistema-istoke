import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'web_notifications.dart';

/// Ponto único de notificação — escolhe a implementação certa por
/// plataforma (Web: firebase_messaging + Notification API do navegador
/// vs mobile: firebase_messaging + flutter_local_notifications).
class AppNotifications {
  AppNotifications._();

  static const _storage = FlutterSecureStorage();

  static Future<bool> requestPermission() async {
    if (kIsWeb) return _initWeb();
    try {
      await NotificationService.instance.initialize();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _initWeb() async {
    final granted = await requestWebNotificationPermission();
    if (!granted) return false;

    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken(vapidKey: AppConstants.vapidKey);
      if (token != null) {
        await _storage.write(key: AppConstants.fcmTokenKey, value: token);
        await _registerToken(token);
      }

      // Só chega aqui com a aba aberta (foreground) -- push com app
      // fechado/aba minimizada é entregue pelo firebase-messaging-sw.js.
      FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification != null) {
          showWebNotification(notification.title ?? 'StockIQ', notification.body ?? '');
        }
      });

      messaging.onTokenRefresh.listen((newToken) async {
        await _storage.write(key: AppConstants.fcmTokenKey, value: newToken);
        await _registerToken(newToken);
      });
    } catch (_) {
      // Fogo-e-esquece: falha ao pegar token FCM não pode travar o login.
    }
    return true;
  }

  static Future<void> _registerToken(String token) async {
    try {
      await ApiService.instance.client.post('/users/me/fcm-token', data: {
        'token': token,
        'platform': 'web',
      });
    } catch (_) {}
  }

  static Future<void> notify(String title, String body) async {
    if (kIsWeb) {
      showWebNotification(title, body);
    } else {
      await NotificationService.instance.showAlert(title, body);
    }
  }
}
