import 'dart:html' as html;

/// iPhone/iPad no navegador, ainda não instalado na tela inicial. No iOS não
/// existe APK: o jeito de "baixar" é o PWA (Compartilhar > Adicionar à Tela
/// de Início), e o Safari não avisa sozinho -- então o app avisa.
bool get shouldSuggestHomeScreenInstall {
  final ua = html.window.navigator.userAgent;
  final isIOS = RegExp('iPhone|iPad|iPod').hasMatch(ua) ||
      (html.window.navigator.platform == 'MacIntel' && (html.window.navigator.maxTouchPoints ?? 0) > 1);
  final standalone = html.window.matchMedia('(display-mode: standalone)').matches;
  return isIOS && !standalone;
}

void openInstallPage() => html.window.location.assign('/instalar.html');
