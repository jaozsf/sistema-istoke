import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../models/logistics_models.dart';

// Componentes no padrão de interface do iOS (Human Interface Guidelines):
// título grande que encolhe ao rolar, listas agrupadas inset, alerta
// Cupertino, haptics. Todas as telas novas montam a partir daqui pra ficar
// com a mesma cara.

class Haptics {
  Haptics._();
  static void tap() => HapticFeedback.selectionClick();
  static void success() => HapticFeedback.mediumImpact();
  static void warning() => HapticFeedback.heavyImpact();
}

// ── Scaffold com Large Title ──────────────────────────────────────────────────

class IosPage extends StatelessWidget {
  final String title;
  final List<Widget> slivers;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Future<void> Function()? onRefresh;
  final PreferredSizeWidget? bottom;
  final bool largeTitle;

  const IosPage({
    super.key,
    required this.title,
    required this.slivers,
    this.actions,
    this.floatingActionButton,
    this.onRefresh,
    this.bottom,
    this.largeTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final appBar = largeTitle
        ? SliverAppBar.large(
            title: Text(title),
            pinned: true,
            backgroundColor: bg,
            surfaceTintColor: Colors.transparent,
            actions: actions,
            bottom: bottom,
          )
        : SliverAppBar(
            title: Text(title),
            pinned: true,
            backgroundColor: bg,
            surfaceTintColor: Colors.transparent,
            actions: actions,
            bottom: bottom,
          );

    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: CustomScrollView(
        slivers: [
          appBar,
          if (onRefresh != null)
            CupertinoSliverRefreshControl(onRefresh: () async {
              Haptics.tap();
              await onRefresh!();
            }),
          for (final s in slivers)
            SliverCenter(sliver: s),
          // espaço pro tab bar flutuante + FAB
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

/// Limita a largura de um sliver em telas largas (iPad/desktop) -- mesmo
/// papel do PageContainer, mas pra CustomScrollView.
class SliverCenter extends StatelessWidget {
  final Widget sliver;
  final double maxWidth;
  const SliverCenter({super.key, required this.sliver, this.maxWidth = 900});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pad = context.isWide ? math.max(16.0, (width - maxWidth) / 2) : 0.0;
    return SliverPadding(padding: EdgeInsets.symmetric(horizontal: pad), sliver: sliver);
  }
}

// ── Lista agrupada (Settings style) ───────────────────────────────────────────

class IosSection extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;
  final Widget? trailingHeader;

  const IosSection({super.key, this.header, this.footer, required this.children, this.trailingHeader});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      header!.toUpperCase(),
                      style: TextStyle(fontSize: 13, color: muted, letterSpacing: .2),
                    ),
                  ),
                  if (trailingHeader != null) trailingHeader!,
                ],
              ),
            ),
          Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Divider(height: .5, thickness: .5, indent: 60, color: theme.colorScheme.outline),
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(footer!, style: TextStyle(fontSize: 13, color: muted)),
            ),
        ],
      ),
    );
  }
}

class IosTile extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? value;
  final VoidCallback? onTap;
  final bool chevron;
  final bool destructive;

  const IosTile({
    super.key,
    this.icon,
    this.iconColor,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.value,
    this.onTap,
    this.chevron = true,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final color = iconColor ?? AppTheme.accentOf(context);
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              Haptics.tap();
              onTap!();
            },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)]
              else if (icon != null) ...[
                IconBadge(icon: icon!, color: color),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(color: destructive ? AppTheme.danger : null),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              if (value != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(value!, style: TextStyle(fontSize: 16, color: muted)),
                ),
              if (trailing != null) Padding(padding: const EdgeInsets.only(left: 8), child: trailing!),
              if (onTap != null && chevron)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(CupertinoIcons.chevron_forward, size: 16, color: muted.withValues(alpha: .6)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ícone dentro de quadrado arredondado colorido (como no Ajustes do iOS).
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconBadge({super.key, required this.icon, required this.color, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * .26)),
      child: Icon(icon, color: Colors.white, size: size * .6),
    );
  }
}

// ── Etapa do pedido ───────────────────────────────────────────────────────────

class StagePill extends StatelessWidget {
  final OrderStage stage;
  final bool compact;
  const StagePill({super.key, required this.stage, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: stage.color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stage.icon, size: compact ? 12 : 14, color: stage.color),
          const SizedBox(width: 4),
          Text(stage.label,
              style: TextStyle(fontSize: compact ? 11 : 12, fontWeight: FontWeight.w600, color: stage.color)),
        ],
      ),
    );
  }
}

// ── Diálogos Cupertino ────────────────────────────────────────────────────────

Future<bool> showIosConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirmar',
  bool destructive = false,
}) async {
  final ok = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: message == null ? null : Padding(padding: const EdgeInsets.only(top: 6), child: Text(message)),
      actions: [
        CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        CupertinoDialogAction(
          isDefaultAction: !destructive,
          isDestructiveAction: destructive,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void showIosToast(BuildContext context, String message, {bool error = false}) {
  if (error) {
    Haptics.warning();
  } else {
    Haptics.success();
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(error ? CupertinoIcons.exclamationmark_circle_fill : CupertinoIcons.checkmark_alt_circle_fill,
              color: error ? AppTheme.danger : AppTheme.aqua, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
    ));
}

// ── Contador +/- (conferência, quantidade de caixas) ──────────────────────────

class Stepper2 extends StatelessWidget {
  final int value;
  final int min;
  final int? max;
  final ValueChanged<int> onChanged;
  const Stepper2({super.key, required this.value, required this.onChanged, this.min = 0, this.max});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget btn(IconData icon, int delta) {
      final next = value + delta;
      final enabled = next >= min && (max == null || next <= max!);
      return SizedBox(
        width: 40,
        height: 34,
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 18,
          onPressed: enabled
              ? () {
                  Haptics.tap();
                  onChanged(next);
                }
              : null,
          icon: Icon(icon),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(CupertinoIcons.minus, -1),
          SizedBox(
            width: 44,
            child: Text('$value', textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          ),
          btn(CupertinoIcons.plus, 1),
        ],
      ),
    );
  }
}

// ── Caixa 3D (isométrica) ─────────────────────────────────────────────────────

/// Desenha a caixa padrão em perspectiva isométrica, proporcional às
/// medidas reais (C x L x A) -- o admin vê na hora se cadastrou uma caixa
/// "achatada" ou "torre" por engano. CustomPainter puro: roda igual em
/// iPhone, Android e web, sem WebGL nem asset 3D.
class Box3D extends StatelessWidget {
  final double length, width, height;
  final int? units;
  final double size;
  const Box3D({super.key, required this.length, required this.width, required this.height, this.units, this.size = 160});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (_, t, __) => CustomPaint(
        size: Size.square(size),
        painter: _Box3DPainter(
          l: math.max(length, 1), w: math.max(width, 1), h: math.max(height, 1) * t.clamp(0.05, 1.2),
          units: units, dark: dark,
        ),
      ),
    );
  }
}

class _Box3DPainter extends CustomPainter {
  final double l, w, h;
  final int? units;
  final bool dark;
  _Box3DPainter({required this.l, required this.w, required this.h, this.units, required this.dark});

  @override
  void paint(Canvas canvas, Size s) {
    const cos30 = 0.8660254, sin30 = 0.5;
    // Projeção isométrica: x (comprimento) pra direita-baixo, y (largura)
    // pra esquerda-baixo, z (altura) pra cima.
    Offset iso(double x, double y, double z) => Offset((x - y) * cos30, (x + y) * sin30 - z);

    final corners = [
      for (final x in [0.0, l]) for (final y in [0.0, w]) for (final z in [0.0, h]) iso(x, y, z),
    ];
    final minX = corners.map((o) => o.dx).reduce(math.min), maxX = corners.map((o) => o.dx).reduce(math.max);
    final minY = corners.map((o) => o.dy).reduce(math.min), maxY = corners.map((o) => o.dy).reduce(math.max);
    final scale = math.min(s.width * .86 / (maxX - minX), s.height * .86 / (maxY - minY));
    final origin = Offset(
      s.width / 2 - (minX + maxX) / 2 * scale,
      s.height / 2 - (minY + maxY) / 2 * scale,
    );
    Offset p(double x, double y, double z) => origin + iso(x, y, z) * scale;

    Path face(List<Offset> pts) => Path()..addPolygon(pts, true);
    final top   = face([p(0, 0, h), p(l, 0, h), p(l, w, h), p(0, w, h)]);
    final right = face([p(l, 0, 0), p(l, w, 0), p(l, w, h), p(l, 0, h)]);
    final left  = face([p(0, w, 0), p(l, w, 0), p(l, w, h), p(0, w, h)]);

    // Sombra no chão
    canvas.drawPath(
      face([p(0, 0, 0), p(l, 0, 0), p(l, w, 0), p(0, w, 0)]).shift(const Offset(0, 6)),
      Paint()
        ..color = Colors.black.withValues(alpha: dark ? .5 : .12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.drawPath(top, Paint()..color = dark ? AppTheme.aqua : AppTheme.foam);
    canvas.drawPath(right, Paint()..color = AppTheme.lagoon);
    canvas.drawPath(left, Paint()..color = AppTheme.deep);

    // Fita adesiva no topo
    final tape = Paint()
      ..color = (dark ? AppTheme.abyss : AppTheme.lagoon).withValues(alpha: .35)
      ..strokeWidth = math.max(3, w * scale * .08)
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(p(0, w / 2, h), p(l, w / 2, h), tape);

    final edge = Paint()
      ..color = AppTheme.abyss.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.round;
    for (final f in [top, right, left]) {
      canvas.drawPath(f, edge);
    }

    if (units != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: '×$units',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final c = p(l, w / 2, h / 2);
      tp.paint(canvas, c - Offset(tp.width / 2 + 4, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _Box3DPainter old) =>
      old.l != l || old.w != w || old.h != h || old.units != units || old.dark != dark;
}

// ── Card de número grande ─────────────────────────────────────────────────────

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const StatTile({super.key, required this.label, required this.value, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap == null
            ? null
            : () {
                Haptics.tap();
                onTap!();
              },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconBadge(icon: icon, color: color, size: 28),
                  const Spacer(),
                  Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontSize: 26)),
                ],
              ),
              const SizedBox(height: 10),
              Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
