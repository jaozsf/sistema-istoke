import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Orientação: portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar transparente
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Locale pt_BR pro DateFormat (usado no dashboard) -- sem isso o intl
  // lanca LocaleDataException e o widget quebra em silencio (tela cinza)
  await initializeDateFormatting('pt_BR', null);

  // Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.web);

  // Notificações push (web: precisa de firebase-messaging-sw.js + VAPID key
  // que nao existem nesse projeto ainda -- getToken() trava esperando o
  // service worker registrar e nunca retorna, travando o app inteiro em
  // tela branca. Pula no web ate isso ser configurado de verdade.)
  if (!kIsWeb) {
    try {
      await NotificationService.instance.initialize();
    } catch (_) {
      // push notifications indisponivel sem projeto Firebase real (dev)
    }
  }

  runApp(
    const ProviderScope(
      child: StockIQApp(),
    ),
  );
}

class StockIQApp extends ConsumerWidget {
  const StockIQApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'StockIQ',
      debugShowCheckedModeBanner: false,
      theme:      AppTheme.light,
      darkTheme:  AppTheme.dark,
      themeMode:  ThemeMode.system,
      routerConfig: router,
      builder: (context, child) {
        // Aplica escala de texto fixa (evita quebras de layout)
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        );
      },
    );
  }
}
