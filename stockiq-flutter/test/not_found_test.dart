import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockiq/core/theme/app_theme.dart';
import 'package:stockiq/features/errors/not_found_screen.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(375, 812), const Size(1440, 900)]) {
    testWidgets('404 cabe na tela ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(theme: AppTheme.dark, home: const NotFoundScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Página não encontrada'), findsOneWidget);
      expect(find.text('VOLTAR AO INÍCIO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
