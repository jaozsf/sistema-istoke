import 'dart:async' show unawaited;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/api_service.dart';
import 'core/services/auth_service.dart';
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

  // Status bar transparente (cor dos ícones acompanha o tema, ver
  // AnnotatedRegion em StockIQApp)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  if (!kIsWeb) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Locale pt_BR pro DateFormat (usado no dashboard) -- sem isso o intl
  // lanca LocaleDataException e o widget quebra em silencio (tela cinza)
  await initializeDateFormatting('pt_BR', null);

  // Firebase — web precisa das options explícitas (sem arquivo nativo pra
  // ler). Android/iOS lêem sozinhos de google-services.json/
  // GoogleService-Info.plist, não passa nada aqui.
  await Firebase.initializeApp(options: kIsWeb ? DefaultFirebaseOptions.web : null);

  // Pedido de permissão de notificação fica pro login (perto de um gesto
  // do usuário — navegador tende a bloquear pedido feito sem interação).
  final container = ProviderContainer();

  // Sessão não cai mais quando o JWT expira com o app fechado: o
  // ApiService renova pelo Firebase e só desloga se isso falhar.
  AuthService.installSessionRefresh(
    onExpired: () {
      // Guarda: o próprio signOut chama a API (remover token de push), que
      // pode dar 401 de novo e cair aqui -- sem isso vira loop.
      final auth = container.read(authStateProvider);
      if (auth.isLoading || !(auth.valueOrNull?.isLoggedIn ?? false)) return;
      container.read(authStateProvider.notifier).signOut();
    },
  );
  // Acorda backend/banco em paralelo com o boot (cold start da Vercel)
  unawaited(ApiService.instance.warmUp());

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const StockIQApp(),
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
      // Rolagem elástica estilo iOS em toda plataforma
      scrollBehavior: const _IosScrollBehavior(),
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        // Respeita o tamanho de texto do sistema (acessibilidade do iPhone),
        // mas trava num teto pra não quebrar layout.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.25,
            child: child!,
          ),
        );
      },
    );
  }
}

class _IosScrollBehavior extends MaterialScrollBehavior {
  const _IosScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
