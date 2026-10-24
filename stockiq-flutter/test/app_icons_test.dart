import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stockiq/core/providers/app_icon_provider.dart';
import 'package:stockiq/core/theme/app_theme.dart';
import 'package:stockiq/shared/widgets/app_icons.dart';
import 'package:stockiq/shared/widgets/app_widgets.dart';

void main() {
  testWidgets('todos os desenhos e emojis renderizam em 3 tamanhos', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Wrap(children: [
            for (final size in [16.0, 48.0, 128.0]) ...[
              for (final g in iconGlyphs)
                AppIconView(choice: AppIconChoice(kind: IconKind.glyph, value: g.id, colorId: 'orange'), size: size),
              for (final e in iconEmojis)
                AppIconView(choice: AppIconChoice(kind: IconKind.emoji, value: e, colorId: 'purple'), size: size),
            ],
          ]),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(iconGlyphs.length, greaterThanOrEqualTo(10));
  });

  testWidgets('AppLogo segue o ícone escolhido e a escolha é salva', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appIconProvider.notifier).set(
          const AppIconChoice(kind: IconKind.emoji, value: '🥤', colorId: 'green'),
        );
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: AppLogo(size: 48))),
    ));
    expect(find.text('🥤'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_icon'), contains('green'));
  });
}
