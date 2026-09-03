import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/providers/theme_provider.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Por padrao, build release troca erro de widget por uma caixa cinza sem
  // texto (por design do Flutter) -- foi exatamente isso que escondeu bugs
  // reais (locale, import quebrado) até a hora de testar. Sempre mostra a
  // mensagem, em qualquer modo.
  ErrorWidget.builder = (FlutterErrorDetails details) => Material(
        color: const Color(0xFFFDECEC),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Erro nessa tela:\n${details.exceptionAsString()}',
              style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );

  // Orientação: portrait only só em celular -- web/desktop não tem esse
  // conceito de orientação de tela, travar lá não faz sentido.
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Status bar transparente
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Locale pt_BR pro DateFormat (usado no dashboard) -- sem isso o intl
  // lanca LocaleDataException e o widget quebra em silencio (tela cinza)
  await initializeDateFormatting('pt_BR', null);

  // Firebase — web precisa das options explícitas (sem arquivo nativo pra
  // ler). Android/iOS lêem sozinhos de google-services.json/
  // GoogleService-Info.plist, não passa nada aqui.
  await Firebase.initializeApp(options: kIsWeb ? DefaultFirebaseOptions.web : null);

  // Pedido de permissão de notificação fica pro login (perto de um gesto
  // do usuário — navegador tende a bloquear pedido feito sem interação).
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
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'StockIQ',
      debugShowCheckedModeBanner: false,
      theme:      AppTheme.light,
      darkTheme:  AppTheme.dark,
      themeMode:  themeMode,
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
