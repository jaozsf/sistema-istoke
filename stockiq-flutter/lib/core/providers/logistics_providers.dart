import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/logistics_models.dart';
import '../services/logistics_api_service.dart';

final logisticsApiProvider = Provider((_) => LogisticsApiService());

final boxStandardsProvider = FutureProvider<Map<String, BoxStandard>>((ref) async {
  final list = await ref.watch(logisticsApiProvider).getBoxStandards();
  return {for (final b in list) b.productId: b};
});

final distributorsProvider = FutureProvider.family<List<Distributor>, bool>(
  (ref, includeInactive) => ref.watch(logisticsApiProvider).getDistributors(includeInactive: includeInactive),
);

final customersProvider = FutureProvider.family<List<Customer>, String>(
  (ref, q) => ref.watch(logisticsApiProvider).getCustomers(q: q),
);

final orderSummaryProvider = FutureProvider<OrderSummary>(
  (ref) => ref.watch(logisticsApiProvider).getOrderSummary(),
);

/// Filtro: null = todos, 'abertos', ou o valor de uma etapa.
final ordersProvider = FutureProvider.family<List<Order>, String?>(
  (ref, status) => ref.watch(logisticsApiProvider).getOrders(status: status),
);

final orderDetailProvider = FutureProvider.family<Order, String>(
  (ref, id) => ref.watch(logisticsApiProvider).getOrder(id),
);

/// Depois de qualquer mudança num pedido: lista, contadores e detalhe.
void invalidateOrders(WidgetRef ref, [String? orderId]) {
  ref.invalidate(ordersProvider);
  ref.invalidate(orderSummaryProvider);
  if (orderId != null) ref.invalidate(orderDetailProvider(orderId));
}
