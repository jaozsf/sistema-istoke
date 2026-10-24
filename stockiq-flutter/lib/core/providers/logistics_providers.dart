import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/logistics_models.dart';
import '../services/logistics_api_service.dart';
import 'cache_for.dart';

final logisticsApiProvider = Provider((_) => LogisticsApiService());

final boxStandardsProvider = FutureProvider<Map<String, BoxStandard>>((ref) async {
  final list = await ref.watch(logisticsApiProvider).getBoxStandards();
  return {for (final b in list) b.productId: b};
});

final distributorsProvider = FutureProvider.family<List<Distributor>, bool>(
  (ref, includeInactive) => ref.watch(logisticsApiProvider).getDistributors(includeInactive: includeInactive),
);

// Uma entrada por texto digitado na busca -- autoDispose evita acumular.
final customersProvider = FutureProvider.autoDispose.family<List<Customer>, String>((ref, q) {
  ref.cacheFor(const Duration(minutes: 2));
  return ref.watch(logisticsApiProvider).getCustomers(q: q);
});

final orderSummaryProvider = FutureProvider<OrderSummary>(
  (ref) => ref.watch(logisticsApiProvider).getOrderSummary(),
);

/// Filtro: null = todos, 'abertos', ou o valor de uma etapa.
final ordersProvider = FutureProvider.autoDispose.family<List<Order>, String?>((ref, status) {
  ref.cacheFor(const Duration(minutes: 2));
  return ref.watch(logisticsApiProvider).getOrders(status: status);
});

final orderDetailProvider = FutureProvider.autoDispose.family<Order, String>((ref, id) {
  ref.cacheFor(const Duration(minutes: 1));
  return ref.watch(logisticsApiProvider).getOrder(id);
});

/// Depois de qualquer mudança num pedido: lista, contadores e detalhe.
void invalidateOrders(WidgetRef ref, [String? orderId]) {
  ref.invalidate(ordersProvider);
  ref.invalidate(orderSummaryProvider);
  if (orderId != null) ref.invalidate(orderDetailProvider(orderId));
}
