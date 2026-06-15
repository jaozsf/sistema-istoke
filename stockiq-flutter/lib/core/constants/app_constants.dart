class AppConstants {
  AppConstants._();

  // API
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1'; // Android emulator
  // static const String baseUrl = 'http://localhost:8000/api/v1'; // iOS simulator
  // static const String baseUrl = 'https://api.seudominio.com/api/v1'; // produção

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Storage keys
  static const String tokenKey        = 'auth_token';
  static const String userKey         = 'current_user';
  static const String fcmTokenKey     = 'fcm_token';
  static const String themeKey        = 'app_theme';

  // Paginação
  static const int defaultPageSize    = 50;

  // QR
  static const String qrPrefix       = 'STOCKIQ:';

  // Roles
  static const String roleAdmin       = 'admin';
  static const String roleManager     = 'manager';
  static const String roleOperator    = 'operator';

  // Notificações
  static const String channelId      = 'stockiq_channel';
  static const String channelName    = 'StockIQ Alertas';
  static const String channelDesc    = 'Alertas de estoque e movimentações';
}
