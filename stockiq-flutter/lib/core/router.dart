import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'utils/responsive.dart';
import '../shared/widgets/app_widgets.dart';
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

/// Um item de navegação -- alimenta tanto BottomNavigationBarItem (mobile)
/// quanto NavigationRailDestination (tablet/desktop) sem duplicar a lista.
typedef _NavItem = (IconData icon, IconData activeIcon, String label);

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

    const _NavItem dashboardItem = (Icons.dashboard_outlined, Icons.dashboard, 'Início');
    const _NavItem productsItem  = (Icons.inventory_2_outlined, Icons.inventory_2, 'Produtos');
    const _NavItem stockItem     = (Icons.warehouse_outlined, Icons.warehouse, 'Estoque');
    const _NavItem qrItem        = (Icons.qr_code_scanner, Icons.qr_code_scanner, 'QR Code');
    const _NavItem aiItem        = (Icons.auto_awesome_outlined, Icons.auto_awesome, 'IA');

    final navItems = isManager
        ? const [dashboardItem, productsItem, stockItem, qrItem, aiItem]
        : const [productsItem, stockItem, qrItem];

    var currentIndex = routes.indexWhere((r) => location.startsWith(r));
    if (currentIndex < 0) currentIndex = 0;

    // Chave pela raiz da aba (não pela location inteira) -- troca de aba
    // dispara a transição, mas navegar dentro da mesma aba (ex: abrir um
    // produto) não, porque isso já anima via push normal do Navigator.
    final tabRoot = routes[currentIndex];

    final breakpoint = context.breakpoint;
    if (breakpoint == Breakpoint.mobile) {
      return Scaffold(
        body: _AnimatedTabBody(tabKey: tabRoot, child: child),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) => context.go(routes[i]),
          items: [
            for (final item in navItems)
              BottomNavigationBarItem(
                icon: Icon(item.$1),
                activeIcon: _PopIcon(icon: item.$2),
                label: item.$3,
              ),
          ],
        ),
      );
    }

    final extended = breakpoint == Breakpoint.desktop;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 200,
            selectedIndex: currentIndex,
            onDestinationSelected: (i) => context.go(routes[i]),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: extended
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(width: 8),
                        AppLogo(size: 32),
                        SizedBox(width: 10),
                        Text('StockIQ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    )
                  : const AppLogo(size: 32),
            ),
            destinations: [
              for (final item in navItems)
                NavigationRailDestination(
                  icon: Icon(item.$1),
                  selectedIcon: _PopIcon(icon: item.$2),
                  label: Text(item.$3),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _AnimatedTabBody(tabKey: tabRoot, child: child)),
        ],
      ),
    );
  }
}

// ── Animação de troca de aba ──────────────────────────────────────────────────

/// Fade + leve slide vertical ao trocar de aba do bottom nav / rail.
/// Chaveado pela raiz da rota (não pela location completa) pra não disparar
/// de novo quando o usuário só navega dentro da mesma aba.
class _AnimatedTabBody extends StatelessWidget {
  final String tabKey;
  final Widget child;
  const _AnimatedTabBody({required this.tabKey, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, .02), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(tabKey), child: child),
    );
  }
}

/// Ícone ativo do bottom nav / rail "estoura" (pop-in) toda vez que vira o
/// selecionado -- só um TweenAnimationBuilder de escala, sem controller
/// manual pra manter (dispara sozinho quando o widget monta).
class _PopIcon extends StatelessWidget {
  final IconData icon;
  const _PopIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Icon(icon),
    );
  }
}
