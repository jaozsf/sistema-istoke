import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockiq/core/providers/auth_provider.dart';
import 'package:stockiq/core/providers/logistics_providers.dart';
import 'package:stockiq/features/orders/order_detail_screen.dart';
import 'package:stockiq/shared/models/user_model.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stockiq/core/theme/app_theme.dart';
import 'package:stockiq/features/orders/orders_screen.dart';
import 'package:stockiq/shared/models/logistics_models.dart';
import 'package:stockiq/shared/widgets/ios_widgets.dart';

Map<String, dynamic> _orderJson(String status) => {
      'id': 'o1',
      'number': 42,
      'status': status,
      'branch_id': 'b1',
      'customer_id': 'c1',
      'customer_name': 'Bar do Zé com nome bem comprido pra testar quebra de linha',
      'customer_city': 'Maringá/PR',
      'seller_id': 'u1',
      'seller_name': 'Vendedor',
      'distributor_id': null,
      'distributor_name': null,
      'notes': null,
      'invoice_number': null,
      'tracking_code': null,
      'check_notes': null,
      'stock_deducted': true,
      'needs_production': true,
      'total_boxes': 4,
      'total_units': 100,
      'checked_boxes': 2,
      'total_amount': '280.00',
      'total_weight_kg': 10.0,
      'created_at': '2026-10-24T12:00:00Z',
      'updated_at': '2026-10-24T12:00:00Z',
      'dispatched_at': null,
      'items': [
        {
          'id': 'i1', 'product_id': 'p1', 'product_name': 'Copo Twister 500ml', 'product_sku': 'COP-TWI-500',
          'quantity_boxes': 4, 'units_per_box': 25, 'quantity_units': 100, 'box_weight_kg': '2.500',
          'unit_price': '2.80', 'has_art': true, 'has_border': false, 'art_notes': null,
          'checked_boxes': 2, 'is_checked': false,
        },
      ],
      'events': [
        {'id': 'e1', 'from_status': null, 'to_status': 'enviado', 'note': null, 'user_id': 'u1', 'user_name': 'Vendedor', 'created_at': '2026-10-24T12:00:00Z'},
      ],
      'allowed_transitions': ['em_producao', 'cancelado'],
    };

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR', null));

  test('Order.fromJson + ação principal', () {
    final o = Order.fromJson(_orderJson('enviado'));
    expect(o.code, '#0042');
    expect(o.primaryAction, OrderStage.emProducao);
    expect(o.canCancel, isTrue);
    expect(o.items.single.customization, 'Arte');
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('OrderCard e Box3D renderizam sem overflow (${theme.brightness.name})', (tester) async {
      tester.view.physicalSize = const Size(375, 812); // iPhone 13 mini
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              OrderCard(order: Order.fromJson(_orderJson('em_separacao'))),
              const SizedBox(height: 16),
              const Center(child: Box3D(length: 40, width: 30, height: 35, units: 25)),
              for (final s in OrderStage.values) StagePill(stage: s),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('#0042'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final status in ['enviado', 'em_separacao', 'despachado', 'cancelado']) {
    testWidgets('Detalhe do pedido sem overflow no iPhone ($status)', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      const shipping = UserModel(
        id: 'u2', email: 'x@y.com', fullName: 'Expedição', role: 'shipping',
        isActive: true, companyId: 'c', createdAt: '2026-10-24',
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(shipping),
          orderDetailProvider('o1').overrideWith((ref) async => Order.fromJson(_orderJson(status))),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const OrderDetailScreen(id: 'o1')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Pedido #0042'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
