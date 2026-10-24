import 'package:dio/dio.dart';
import '../../shared/models/logistics_models.dart';
import 'api_service.dart';

/// Pedidos, padrões de caixa, distribuidoras e clientes.
class LogisticsApiService {
  final Dio _dio = ApiService.instance.client;

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      throw parseApiError(e);
    }
  }

  // ── Padrões de caixa ─────────────────────────────────────────────────────

  Future<List<BoxStandard>> getBoxStandards() => _call(() async {
        final r = await _dio.get('/box-standards');
        return (r.data as List).map((e) => BoxStandard.fromJson(e)).toList();
      });

  Future<BoxStandard> saveBoxStandard(String productId, Map<String, dynamic> data) => _call(() async {
        final r = await _dio.put('/box-standards/$productId', data: data);
        return BoxStandard.fromJson(r.data);
      });

  Future<void> deleteBoxStandard(String productId) => _call(() => _dio.delete('/box-standards/$productId'));

  // ── Distribuidoras ────────────────────────────────────────────────────────

  Future<List<Distributor>> getDistributors({bool includeInactive = false}) => _call(() async {
        final r = await _dio.get('/distributors', queryParameters: {'include_inactive': includeInactive});
        return (r.data as List).map((e) => Distributor.fromJson(e)).toList();
      });

  Future<Distributor> saveDistributor(String? id, Map<String, dynamic> data) => _call(() async {
        final r = id == null ? await _dio.post('/distributors', data: data) : await _dio.put('/distributors/$id', data: data);
        return Distributor.fromJson(r.data);
      });

  Future<void> deactivateDistributor(String id) => _call(() => _dio.delete('/distributors/$id'));

  // ── Clientes ──────────────────────────────────────────────────────────────

  Future<List<Customer>> getCustomers({String? q}) => _call(() async {
        final r = await _dio.get('/customers', queryParameters: {if (q != null && q.isNotEmpty) 'q': q});
        return (r.data as List).map((e) => Customer.fromJson(e)).toList();
      });

  Future<Customer> saveCustomer(String? id, Map<String, dynamic> data) => _call(() async {
        final r = id == null ? await _dio.post('/customers', data: data) : await _dio.put('/customers/$id', data: data);
        return Customer.fromJson(r.data);
      });

  // ── Pedidos ───────────────────────────────────────────────────────────────

  Future<OrderSummary> getOrderSummary() => _call(() async {
        final r = await _dio.get('/orders/summary');
        return OrderSummary.fromJson(r.data);
      });

  Future<List<Order>> getOrders({String? status}) => _call(() async {
        final r = await _dio.get('/orders', queryParameters: {if (status != null) 'status': status});
        return (r.data as List).map((e) => Order.fromJson(e)).toList();
      });

  Future<Order> getOrder(String id) => _call(() async => Order.fromJson((await _dio.get('/orders/$id')).data));

  Future<Order> createOrder({
    required String customerId,
    String? distributorId,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) =>
      _call(() async {
        final r = await _dio.post('/orders', data: {
          'customer_id': customerId,
          'distributor_id': distributorId,
          'notes': notes,
          'items': items,
        });
        return Order.fromJson(r.data);
      });

  Future<Order> updateOrder(String id, {String? distributorId, String? notes}) => _call(() async {
        final r = await _dio.patch('/orders/$id', data: {
          if (distributorId != null) 'distributor_id': distributorId,
          if (notes != null) 'notes': notes,
        });
        return Order.fromJson(r.data);
      });

  Future<Order> transition(String id, OrderStage to, {String? note, String? invoiceNumber, String? trackingCode}) =>
      _call(() async {
        final r = await _dio.post('/orders/$id/transition', data: {
          'to_status': to.value,
          if (note != null && note.isNotEmpty) 'note': note,
          if (invoiceNumber != null && invoiceNumber.isNotEmpty) 'invoice_number': invoiceNumber,
          if (trackingCode != null && trackingCode.isNotEmpty) 'tracking_code': trackingCode,
        });
        return Order.fromJson(r.data);
      });

  Future<Order> checkItem(String orderId, String itemId, int checkedBoxes) => _call(() async {
        final r = await _dio.put('/orders/$orderId/items/$itemId/check', data: {'checked_boxes': checkedBoxes});
        return Order.fromJson(r.data);
      });
}
