import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/products/products_screen.dart';
import '../features/products/product_detail_screen.dart';
import '../features/products/product_form_screen.dart';
import '../features/stock/stock_screen.dart';
import '../features/stock/movement_screen.dart';
import '../features/qr/qr_scanner_screen.dart';
import '../features/qr/qr_viewer_screen.dart';
import '../features/ai_assistant/ai_assistant_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/team/team_activity_screen.dart';
import '../shared/models/user_model.dart';
import 'providers/auth_provider.dart';

// Rotas que só admin/manager pode ver — funcionário (operator) que tentar
// acessar é jogado de volta pra /products.
const _managerOnlyRoutes = ['/dashboard', '/ai', '/team-activity'];

// Navegar a partir de fora da árvore de widgets (ex: tap numa notificação
// push, sem BuildContext próprio) -- ver NotificationService.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull?.isLoggedIn ?? false;
      final isAuth = state.matchedLocation.startsWith('/login');

      if (!isLoggedIn && !isAuth) return '/login';
      if (isLoggedIn && isAuth) return '/dashboard';

      if (isLoggedIn) {
        final user = ref.read(currentUserProvider);
        final isManagerOnlyRoute = _managerOnlyRoutes.any((r) => state.matchedLocation.startsWith(r));
        if (isManagerOnlyRoute && !(user?.isManager ?? false)) return '/products';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),

      // Shell com bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(
            path: '/products',
            builder: (_, __) => const ProductsScreen(),
            routes: [
              GoRoute(path: 'new',     builder: (_, __) => const ProductFormScreen()),
              GoRoute(path: ':id',     builder: (_, s) => ProductDetailScreen(id: s.pathParameters['id']!)),
              GoRoute(path: ':id/edit',builder: (_, s) => ProductFormScreen(productId: s.pathParameters['id'])),
            ],
          ),
          GoRoute(
            path: '/stock',
            builder: (_, __) => const StockScreen(),
            routes: [
              GoRoute(path: 'movement', builder: (_, s) {
                final extra = s.extra as Map<String, dynamic>?;
                return MovementScreen(
                  productId:  extra?['productId'],
                  branchId:   extra?['branchId'],
                  initialType: extra?['type'] ?? 'entrada',
                );
              }),
            ],
          ),
          GoRoute(
            path: '/qr',
            builder: (_, __) => const QRScannerScreen(),
            routes: [
              GoRoute(path: 'view/:productId', builder: (_, s) => QRViewerScreen(productId: s.pathParameters['productId']!)),
            ],
          ),
          GoRoute(path: '/ai',             builder: (_, __) => const AiAssistantScreen()),
          GoRoute(path: '/team-activity',  builder: (_, __) => const TeamActivityScreen()),
          GoRoute(path: '/notifications',  builder: (_, __) => const NotificationsScreen()),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Rota não encontrada: ${state.uri}')),
    ),
  );
});

// ── Shell com BottomNavigationBar ─────────────────────────────────────────────

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final isManager = ref.watch(currentUserProvider)?.isManager ?? false;

    // Funcionário (operator) só mexe com produto/estoque/QR — dashboard e
    // IA ficam reservados pro admin/manager (bloqueado também no redirect).
    final routes = isManager
        ? ['/dashboard', '/products', '/stock', '/qr', '/ai']
        : ['/products', '/stock', '/qr'];

    final items = isManager
        ? const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined),   activeIcon: Icon(Icons.dashboard),        label: 'Início'),
            BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2),      label: 'Produtos'),
            BottomNavigationBarItem(icon: Icon(Icons.warehouse_outlined),   activeIcon: Icon(Icons.warehouse),        label: 'Estoque'),
            BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner),      activeIcon: Icon(Icons.qr_code_scanner),  label: 'QR Code'),
            BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_outlined),activeIcon: Icon(Icons.auto_awesome),     label: 'IA'),
          ]
        : const [
            BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2),      label: 'Produtos'),
            BottomNavigationBarItem(icon: Icon(Icons.warehouse_outlined),   activeIcon: Icon(Icons.warehouse),        label: 'Estoque'),
            BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner),      activeIcon: Icon(Icons.qr_code_scanner),  label: 'QR Code'),
          ];

    var currentIndex = routes.indexWhere((r) => location.startsWith(r));
    if (currentIndex < 0) currentIndex = 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => context.go(routes[i]),
        items: items,
      ),
    );
  }
}
