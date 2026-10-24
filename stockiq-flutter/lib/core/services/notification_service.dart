import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/notification_item.dart';
import '../constants/app_constants.dart';
import '../router.dart';
import 'api_service.dart';

const _storeKey = 'stockiq_notifications';
const _maxStored = 50;

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

    // Salva token FCM localmente e registra no backend (é o backend
    // quem dispara os pushes reais, ex: alerta de estoque baixo).
    final token = await _fcm.getToken();
    if (token != null) {
      await _storage.write(key: AppConstants.fcmTokenKey, value: token);
      await _registerToken(token);
    }

    // Atualiza token quando renovado
    _fcm.onTokenRefresh.listen((newToken) async {
      await _storage.write(key: AppConstants.fcmTokenKey, value: newToken);
      await _registerToken(newToken);
    });
  }

  Future<void> _registerToken(String token) async {
    try {
      await ApiService.instance.client.post('/users/me/fcm-token', data: {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
    } catch (_) {
      // Fogo-e-esquece: falha aqui não pode travar login/inicialização.
    }
  }

  /// Remove o token do backend (chamado no logout) pra não mandar push
  /// pra um aparelho de quem já saiu da conta.
  Future<void> deleteTokenFromBackend() async {
    final token = await _storage.read(key: AppConstants.fcmTokenKey);
    if (token == null) return;
    try {
      await ApiService.instance.client.delete('/users/me/fcm-token/$token');
    } catch (_) {}
  }

  Future<void> _showLocal(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _persist(message);

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
          color: const Color(0xFF14918F),
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
    _navigateTo(response.payload);
  }

  void _handleOpen(RemoteMessage message) {
    _navigateTo(message.data['route']);
  }

  /// Navega a partir de fora da árvore de widgets (tap numa notificação
  /// não tem BuildContext próprio) usando o navigatorKey do GoRouter.
  void _navigateTo(String? route) {
    if (route == null) return;
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    GoRouter.of(context).push(route);
  }

  Future<String?> get fcmToken => _storage.read(key: AppConstants.fcmTokenKey);

  // ── Histórico local (pra tela de Notificações) ──────────────────────────────

  /// Guarda o push recebido no histórico local -- é o que alimenta a tela
  /// de Notificações. Roda tanto no listener de foreground quanto no
  /// handler de background (os dois passam por _showLocal).
  Future<void> _persist(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final item = NotificationItem(
      id: message.messageId ?? '${DateTime.now().microsecondsSinceEpoch}',
      title: notification.title ?? 'StockIQ',
      body: notification.body ?? '',
      type: message.data['type'] ?? 'warning',
      route: message.data['route'],
      receivedAt: DateTime.now(),
      read: false,
    );

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storeKey) ?? [];
    raw.insert(0, jsonEncode(item.toJson()));
    if (raw.length > _maxStored) raw.removeRange(_maxStored, raw.length);
    await prefs.setStringList(_storeKey, raw);
  }

  Future<List<NotificationItem>> getStored() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storeKey) ?? [];
    return raw.map((s) => NotificationItem.fromJson(jsonDecode(s))).toList();
  }

  Future<void> markRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storeKey) ?? [];
    final updated = raw.map((s) {
      final item = NotificationItem.fromJson(jsonDecode(s));
      return jsonEncode((item.id == id ? item.copyWith(read: true) : item).toJson());
    }).toList();
    await prefs.setStringList(_storeKey, updated);
  }

  Future<void> markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storeKey) ?? [];
    final updated = raw
        .map((s) => jsonEncode(NotificationItem.fromJson(jsonDecode(s)).copyWith(read: true).toJson()))
        .toList();
    await prefs.setStringList(_storeKey, updated);
  }

  /// Dispara uma notificação local ad-hoc (não veio de um push do FCM,
  /// veio de algo que o próprio app detectou, ex: estoque baixo).
  Future<void> showAlert(String title, String body) async {
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.channelId,
          AppConstants.channelName,
          channelDescription: AppConstants.channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF14918F),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
