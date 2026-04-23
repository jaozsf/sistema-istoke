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
import 'providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull?.isLoggedIn ?? false;
      final isAuth = state.matchedLocation.startsWith('/login');

      if (!isLoggedIn && !isAuth) return '/login';
      if (isLoggedIn && isAuth) return '/dashboard';
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
          GoRoute(path: '/ai',            builder: (_, __) => const AiAssistantScreen()),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
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

    int currentIndex = switch (true) {
      _ when location.startsWith('/dashboard') => 0,
      _ when location.startsWith('/products')  => 1,
      _ when location.startsWith('/stock')     => 2,
      _ when location.startsWith('/qr')        => 3,
      _ when location.startsWith('/ai')        => 4,
      _ => 0,
    };

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) {
          const routes = ['/dashboard', '/products', '/stock', '/qr', '/ai'];
          context.go(routes[i]);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined),  activeIcon: Icon(Icons.dashboard),       label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2),    label: 'Produtos'),
          BottomNavigationBarItem(icon: Icon(Icons.warehouse_outlined),   activeIcon: Icon(Icons.warehouse),      label: 'Estoque'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner),      activeIcon: Icon(Icons.qr_code_scanner),label: 'QR Code'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_outlined),activeIcon: Icon(Icons.auto_awesome),   label: 'IA'),
        ],
      ),
    );
  }
}
