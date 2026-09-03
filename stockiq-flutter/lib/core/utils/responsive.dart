import 'package:flutter/widgets.dart';

enum Breakpoint { mobile, tablet, desktop }

/// Breakpoints derivados só da largura da tela (MediaQuery) -- sem provider
/// nem InheritedWidget novo, já que é valor puramente derivado.
class Responsive {
  Responsive._();

  static const double tabletMin = 600;
  static const double desktopMin = 1024;

  static Breakpoint of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= desktopMin) return Breakpoint.desktop;
    if (width >= tabletMin) return Breakpoint.tablet;
    return Breakpoint.mobile;
  }

  static bool isMobile(BuildContext context) => of(context) == Breakpoint.mobile;
  static bool isTablet(BuildContext context) => of(context) == Breakpoint.tablet;
  static bool isDesktop(BuildContext context) => of(context) == Breakpoint.desktop;

  /// Tablet ou desktop -- usado pra ligar o layout largo (rail, grid 4
  /// colunas, PageContainer) de uma vez só.
  static bool isWide(BuildContext context) => of(context) != Breakpoint.mobile;
}

extension ResponsiveContext on BuildContext {
  Breakpoint get breakpoint => Responsive.of(this);
  bool get isWide => Responsive.isWide(this);
  bool get isDesktop => Responsive.isDesktop(this);
}
