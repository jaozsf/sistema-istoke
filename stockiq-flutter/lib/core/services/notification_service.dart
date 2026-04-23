import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

// Handler para mensagens em background (top-level obrigatório)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.instance._showLocal(message);
}

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }
  NotificationService._();

  final _fcm     = FirebaseMessaging.instance;
  final _local   = FlutterLocalNotificationsPlugin();
  final _storage = const FlutterSecureStorage();

  Future<void> initialize() async {
    // Solicita permissão
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Canal Android
    const androidChannel = AndroidNotificationChannel(
      AppConstants.channelId,
      AppConstants.channelName,
      description: AppConstants.channelDesc,
      importance: Importance.high,
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(androidChannel);

    // Inicializa local notifications
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
      onDidReceiveNotificationResponse: _onTap,
    );

    // Handlers de mensagens FCM
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_showLocal);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpen);

    // Salva token FCM para enviar ao backend
    final token = await _fcm.getToken();
    if (token != null) {
      await _storage.write(key: AppConstants.fcmTokenKey, value: token);
    }

    // Atualiza token quando renovado
    _fcm.onTokenRefresh.listen((newToken) async {
      await _storage.write(key: AppConstants.fcmTokenKey, value: newToken);
    });
  }

  Future<void> _showLocal(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _local.show(
      notification.hashCode,
      notification.title ?? 'StockIQ',
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.channelId,
          AppConstants.channelName,
          channelDescription: AppConstants.channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF534AB7),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['route'],
    );
  }

  void _onTap(NotificationResponse response) {
    // Navegar para rota específica via payload
    final route = response.payload;
    if (route != null) {
      // router.push(route); — conecta ao GoRouter
    }
  }

  void _handleOpen(RemoteMessage message) {
    final route = message.data['route'];
    if (route != null) {
      // router.push(route);
    }
  }

  Future<String?> get fcmToken => _storage.read(key: AppConstants.fcmTokenKey);
}
