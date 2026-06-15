import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/product_model.dart';
import '../../shared/models/stock_model.dart';
import '../../shared/models/movement_model.dart';
import '../services/stock_api_service.dart';

final _api = StockApiService();

// ── Produtos ──────────────────────────────────────────────────────────────────

final productsProvider = FutureProvider.family<List<ProductModel>, String?>(
  (ref, query) => _api.getProducts(q: query),
);

final productDetailProvider = FutureProvider.family<ProductModel, String>(
  (ref, id) => _api.getProduct(id),
);

final productQRProvider = FutureProvider.family<String, String>(
  (ref, productId) => _api.getProductQR(productId),
);

// ── Estoque ───────────────────────────────────────────────────────────────────

final lowStockProvider = FutureProvider<List<StockModel>>(
  (_) => _api.getLowStock(),
);

final branchStockProvider = FutureProvider.family<List<StockModel>, String>(
  (ref, branchId) => _api.getBranchStock(branchId),
);

// ── Movimentações ─────────────────────────────────────────────────────────────

final movementsProvider = FutureProvider<List<MovementModel>>(
  (_) => _api.getMovements(),
);

// ── IA ────────────────────────────────────────────────────────────────────────

class AINotifier extends StateNotifier<AsyncValue<List<_ChatMsg>>> {
  AINotifier() : super(const AsyncData([]));

  final _api = StockApiService();

  Future<void> ask(String question) async {
    final prev = state.valueOrNull ?? [];
    state = AsyncData([...prev, _ChatMsg(role: 'user', text: question)]);

    final withLoading = state.valueOrNull!;
    state = AsyncData([...withLoading, _ChatMsg(role: 'ai', text: '...')]);

    try {
      final answer = await _api.askAI(question);
      final msgs = state.valueOrNull!;
      final updated = [...msgs];
      updated[updated.length - 1] = _ChatMsg(role: 'ai', text: answer);
      state = AsyncData(updated);
    } catch (e) {
      final msgs = state.valueOrNull!;
      final updated = [...msgs];
      updated[updated.length - 1] = _ChatMsg(role: 'ai', text: 'Erro: ${e.toString()}');
      state = AsyncData(updated);
    }
  }

  void clear() => state = const AsyncData([]);
}

class _ChatMsg {
  final String role;
  final String text;
  _ChatMsg({required this.role, required this.text});
}

final aiProvider = StateNotifierProvider<AINotifier, AsyncValue<List<_ChatMsg>>>(
  (_) => AINotifier(),
);
