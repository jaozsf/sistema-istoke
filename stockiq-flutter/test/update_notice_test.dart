import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stockiq/core/services/update_service.dart';
import 'package:stockiq/core/theme/app_theme.dart';
import 'package:stockiq/shared/widgets/update_notice.dart';

void main() {
  test('mostra aviso uma vez por versão', () async {
    SharedPreferences.setMockInitialValues({'last_seen_version': '1.0.0'});
    final first = await UpdateService.check();
    expect(first?.kind, UpdateKind.installed);
    await UpdateService.markSeen();
    expect(await UpdateService.check(), isNull);
  });

  for (final kind in UpdateKind.values) {
    testWidgets('UpdateSheet cabe no iPhone (${kind.name})', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: SingleChildScrollView(child: UpdateSheet(info: UpdateInfo(kind, appVersion)))),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Olá, temos uma nova atualização para você :)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
