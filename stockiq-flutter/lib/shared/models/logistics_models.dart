import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

// Sem code gen (freezed) de propósito -- mesmo padrão manual de
// notification_item.dart; evita depender de build_runner pra cada campo novo.

double _d(dynamic v) => v == null ? 0 : (v is String ? double.parse(v) : (v as num).toDouble());
double? _dn(dynamic v) => v == null ? null : _d(v);

// ── Etapas do pedido ──────────────────────────────────────────────────────────

enum OrderStage {
  enviado('enviado', 'Enviado', 'Aguardando a fábrica', Icons.send_rounded),
  emProducao('em_producao', 'Produção', 'Arte e borda', Icons.brush_rounded),
  emSeparacao('em_separacao', 'Separação', 'Expedição separando', Icons.inventory_2_rounded),
  conferido('conferido', 'Conferido', 'Pronto pra carregar', Icons.fact_check_rounded),
  despachado('despachado', 'Despachado', 'Com a distribuidora', Icons.local_shipping_rounded),
  cancelado('cancelado', 'Cancelado', 'Pedido cancelado', Icons.cancel_rounded);

  final String value;
  final String label;
  final String hint;
  final IconData icon;
  const OrderStage(this.value, this.label, this.hint, this.icon);

  static OrderStage of(String v) => values.firstWhere((s) => s.value == v, orElse: () => enviado);

  /// Etapas do caminho feliz, na ordem -- pra linha do tempo.
  static const flow = [enviado, emProducao, emSeparacao, conferido, despachado];

  Color get color => switch (this) {
        enviado => AppTheme.info,
        emProducao => const Color(0xFF8E6BD8),
        emSeparacao => AppTheme.warning,
        conferido => AppTheme.lagoon,
        despachado => AppTheme.success,
        cancelado => AppTheme.danger,
      };

  /// Verbo do botão que leva PRA essa etapa
  String get actionLabel => switch (this) {
        enviado => 'Reenviar',
        emProducao => 'Iniciar produção',
        emSeparacao => 'Enviar pra separação',
        conferido => 'Concluir conferência',
        despachado => 'Despachar pra distribuidora',
        cancelado => 'Cancelar pedido',
      };
}

// ── Padrão de caixa ───────────────────────────────────────────────────────────

class BoxStandard {
  final String id;
  final String productId;
  final int unitsPerBox;
  final String? boxType;
  final double? lengthCm, widthCm, heightCm, weightKg;
  final String? notes;

  const BoxStandard({
    required this.id,
    required this.productId,
    required this.unitsPerBox,
    this.boxType,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    this.weightKg,
    this.notes,
  });

  factory BoxStandard.fromJson(Map<String, dynamic> j) => BoxStandard(
        id: j['id'],
        productId: j['product_id'],
        unitsPerBox: j['units_per_box'],
        boxType: j['box_type'],
        lengthCm: _dn(j['length_cm']),
        widthCm: _dn(j['width_cm']),
        heightCm: _dn(j['height_cm']),
        weightKg: _dn(j['weight_kg']),
        notes: j['notes'],
      );

  bool get hasDimensions => (lengthCm ?? 0) > 0 && (widthCm ?? 0) > 0 && (heightCm ?? 0) > 0;
  double? get volumeM3 => hasDimensions ? lengthCm! * widthCm! * heightCm! / 1e6 : null;
}

// ── Distribuidora / Cliente ───────────────────────────────────────────────────

class Distributor {
  final String id;
  final String name;
  final String? cnpj, contactName, phone, email, regions, notes;
  final bool isActive;

  const Distributor({
    required this.id,
    required this.name,
    this.cnpj,
    this.contactName,
    this.phone,
    this.email,
    this.regions,
    this.notes,
    this.isActive = true,
  });

  factory Distributor.fromJson(Map<String, dynamic> j) => Distributor(
        id: j['id'],
        name: j['name'],
        cnpj: j['cnpj'],
        contactName: j['contact_name'],
        phone: j['phone'],
        email: j['email'],
        regions: j['regions'],
        notes: j['notes'],
        isActive: j['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'cnpj': cnpj,
        'contact_name': contactName,
        'phone': phone,
        'email': email,
        'regions': regions,
        'notes': notes,
        'is_active': isActive,
      };
}

class Customer {
  final String id;
  final String name;
  final String? document, phone, email, city, state, address, sellerId;

  const Customer({
    required this.id,
    required this.name,
    this.document,
    this.phone,
    this.email,
    this.city,
    this.state,
    this.address,
    this.sellerId,
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'],
        name: j['name'],
        document: j['document'],
        phone: j['phone'],
        email: j['email'],
        city: j['city'],
        state: j['state'],
        address: j['address'],
        sellerId: j['seller_id'],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'document': document,
        'phone': phone,
        'email': email,
        'city': city,
        'state': state,
        'address': address,
      };

  String get location => [city, state].where((e) => e != null && e.isNotEmpty).join('/');
}

// ── Pedido ────────────────────────────────────────────────────────────────────

class OrderItem {
  final String id;
  final String productId, productName, productSku;
  final int quantityBoxes, unitsPerBox, quantityUnits, checkedBoxes;
  final double? boxWeightKg;
  final double unitPrice;
  final bool hasArt, hasBorder, isChecked;
  final String? artNotes;

  const OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.quantityBoxes,
    required this.unitsPerBox,
    required this.quantityUnits,
    required this.checkedBoxes,
    required this.unitPrice,
    required this.hasArt,
    required this.hasBorder,
    required this.isChecked,
    this.boxWeightKg,
    this.artNotes,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        id: j['id'],
        productId: j['product_id'],
        productName: j['product_name'],
        productSku: j['product_sku'],
        quantityBoxes: j['quantity_boxes'],
        unitsPerBox: j['units_per_box'],
        quantityUnits: j['quantity_units'],
        checkedBoxes: j['checked_boxes'],
        boxWeightKg: _dn(j['box_weight_kg']),
        unitPrice: _d(j['unit_price']),
        hasArt: j['has_art'] ?? false,
        hasBorder: j['has_border'] ?? false,
        isChecked: j['is_checked'] ?? false,
        artNotes: j['art_notes'],
      );

  String get customization => [if (hasArt) 'Arte', if (hasBorder) 'Borda'].join(' + ');
}

class OrderEvent {
  final String? fromStatus;
  final String toStatus;
  final String? note, userName;
  final DateTime createdAt;

  const OrderEvent({this.fromStatus, required this.toStatus, this.note, this.userName, required this.createdAt});

  factory OrderEvent.fromJson(Map<String, dynamic> j) => OrderEvent(
        fromStatus: j['from_status'],
        toStatus: j['to_status'],
        note: j['note'],
        userName: j['user_name'],
        createdAt: DateTime.parse(j['created_at']).toLocal(),
      );
}

class Order {
  final String id;
  final int number;
  final OrderStage stage;
  final String customerId, branchId;
  final String? customerName, customerCity, sellerId, sellerName, distributorId, distributorName;
  final String? notes, invoiceNumber, trackingCode, checkNotes;
  final bool stockDeducted, needsProduction;
  final int totalBoxes, totalUnits, checkedBoxes;
  final double totalAmount, totalWeightKg;
  final DateTime createdAt, updatedAt;
  final DateTime? dispatchedAt;
  final List<OrderItem> items;
  final List<OrderEvent> events;
  final List<OrderStage> allowedTransitions;

  const Order({
    required this.id,
    required this.number,
    required this.stage,
    required this.customerId,
    required this.branchId,
    this.customerName,
    this.customerCity,
    this.sellerId,
    this.sellerName,
    this.distributorId,
    this.distributorName,
    this.notes,
    this.invoiceNumber,
    this.trackingCode,
    this.checkNotes,
    required this.stockDeducted,
    required this.needsProduction,
    required this.totalBoxes,
    required this.totalUnits,
    required this.checkedBoxes,
    required this.totalAmount,
    required this.totalWeightKg,
    required this.createdAt,
    required this.updatedAt,
    this.dispatchedAt,
    required this.items,
    required this.events,
    required this.allowedTransitions,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'],
        number: j['number'],
        stage: OrderStage.of(j['status']),
        customerId: j['customer_id'],
        branchId: j['branch_id'],
        customerName: j['customer_name'],
        customerCity: j['customer_city'],
        sellerId: j['seller_id'],
        sellerName: j['seller_name'],
        distributorId: j['distributor_id'],
        distributorName: j['distributor_name'],
        notes: j['notes'],
        invoiceNumber: j['invoice_number'],
        trackingCode: j['tracking_code'],
        checkNotes: j['check_notes'],
        stockDeducted: j['stock_deducted'] ?? false,
        needsProduction: j['needs_production'] ?? false,
        totalBoxes: j['total_boxes'],
        totalUnits: j['total_units'],
        checkedBoxes: j['checked_boxes'],
        totalAmount: _d(j['total_amount']),
        totalWeightKg: _d(j['total_weight_kg']),
        createdAt: DateTime.parse(j['created_at']).toLocal(),
        updatedAt: DateTime.parse(j['updated_at']).toLocal(),
        dispatchedAt: j['dispatched_at'] != null ? DateTime.parse(j['dispatched_at']).toLocal() : null,
        items: (j['items'] as List).map((e) => OrderItem.fromJson(e)).toList(),
        events: (j['events'] as List).map((e) => OrderEvent.fromJson(e)).toList(),
        allowedTransitions: ((j['allowed_transitions'] as List?) ?? []).map((e) => OrderStage.of(e)).toList(),
      );

  String get code => '#${number.toString().padLeft(4, '0')}';
  double get checkProgress => totalBoxes == 0 ? 0 : checkedBoxes / totalBoxes;
  bool get isOpen => stage != OrderStage.despachado && stage != OrderStage.cancelado;

  /// Próxima etapa "pra frente" que esse usuário pode acionar (botão
  /// principal); cancelamento fica num botão separado.
  OrderStage? get primaryAction =>
      allowedTransitions.where((s) => s != OrderStage.cancelado && s.index > stage.index).firstOrNull;
  bool get canCancel => allowedTransitions.contains(OrderStage.cancelado);
  bool get canReopenCheck => stage == OrderStage.conferido && allowedTransitions.contains(OrderStage.emSeparacao);
}

class OrderSummary {
  final Map<String, int> counts;
  final int openTotal, dispatchedToday;
  const OrderSummary({required this.counts, required this.openTotal, required this.dispatchedToday});

  factory OrderSummary.fromJson(Map<String, dynamic> j) => OrderSummary(
        counts: (j['counts'] as Map).map((k, v) => MapEntry(k as String, v as int)),
        openTotal: j['open_total'],
        dispatchedToday: j['dispatched_today'],
      );

  int of(OrderStage s) => counts[s.value] ?? 0;
}
