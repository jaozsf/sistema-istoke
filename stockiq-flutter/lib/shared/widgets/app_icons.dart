import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Ícones do app que cada pessoa pode escolher (Gestão/Conta → Aparência →
/// Ícone do app): desenhos vetoriais e emojis, todos do mundo de estoque.
/// Desenhos são CustomPainter (vetor puro, nítido em qualquer tamanho, sem
/// asset nem pacote de SVG).

enum IconKind { glyph, emoji }

class IconGlyph {
  final String id;
  final String label;
  final void Function(Canvas canvas, Size s, Paint stroke, Paint fill) paint;
  const IconGlyph(this.id, this.label, this.paint);
}

class IconColor {
  final String id;
  final String label;
  final Gradient gradient;
  const IconColor(this.id, this.label, this.gradient);
}

const iconColors = <IconColor>[
  IconColor('lagoon', 'Lagoon', LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.deep, AppTheme.lagoon, AppTheme.aqua])),
  IconColor('deep', 'Oceano', LinearGradient(colors: [AppTheme.abyss, AppTheme.deep])),
  IconColor('aqua', 'Água', LinearGradient(colors: [AppTheme.lagoon, AppTheme.aqua])),
  IconColor('night', 'Noite', LinearGradient(colors: [Color(0xFF111827), Color(0xFF374151)])),
  IconColor('orange', 'Laranja', LinearGradient(colors: [Color(0xFFE5732D), Color(0xFFF2B33D)])),
  IconColor('purple', 'Roxo', LinearGradient(colors: [Color(0xFF5B3FC4), Color(0xFF9B7BEA)])),
  IconColor('red', 'Vermelho', LinearGradient(colors: [Color(0xFFB4232A), Color(0xFFE5484D)])),
  IconColor('green', 'Verde', LinearGradient(colors: [Color(0xFF1E7F4F), Color(0xFF3CC47C)])),
];

IconColor iconColorById(String id) => iconColors.firstWhere((c) => c.id == id, orElse: () => iconColors.first);

/// Emojis de estoque, logística e loja de copos.
const iconEmojis = <String>[
  '📦', '🥤', '🏭', '🚚', '📊', '🏷️', '🗃️', '📋', '🛒', '🧾', '🏪', '🔢',
  '📈', '🧃', '🥛', '☕', '🧊', '🍹', '🗂️', '📥', '📤', '🏗️', '⚖️', '🔖',
];

// ── Desenhos (coordenadas em fração do tamanho: funcionam de 16 a 512 px) ────

final iconGlyphs = <IconGlyph>[
  IconGlyph('box-bars', 'Caixa com gráfico', (c, s, st, fi) {
    final w = s.width, h = s.height;
    final r = RRect.fromRectAndRadius(Rect.fromLTRB(w * .18, h * .22, w * .82, h * .80), Radius.circular(w * .05));
    c.drawRRect(r, st);
    c.drawLine(Offset(w * .18, h * .39), Offset(w * .82, h * .39), st);
    final bw = w * .1;
    for (var i = 0; i < 3; i++) {
      final bh = h * (.1 + .06 * i);
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * .3 + i * (bw + w * .04), h * .73 - bh, bw, bh), Radius.circular(bw * .35)),
        fi,
      );
    }
  }),
  IconGlyph('open-box', 'Caixa aberta', (c, s, st, fi) {
    final w = s.width, h = s.height;
    c.drawPath(Path()
      ..moveTo(w * .2, h * .42)..lineTo(w * .5, h * .54)..lineTo(w * .8, h * .42)
      ..lineTo(w * .8, h * .74)..lineTo(w * .5, h * .86)..lineTo(w * .2, h * .74)..close(), st);
    c.drawLine(Offset(w * .5, h * .54), Offset(w * .5, h * .86), st);
    c.drawLine(Offset(w * .2, h * .42), Offset(w * .1, h * .28), st);
    c.drawLine(Offset(w * .8, h * .42), Offset(w * .9, h * .28), st);
    c.drawCircle(Offset(w * .5, h * .26), w * .07, fi);
  }),
  IconGlyph('cup', 'Copo', (c, s, st, fi) {
    final w = s.width, h = s.height;
    c.drawPath(Path()
      ..moveTo(w * .28, h * .26)..lineTo(w * .72, h * .26)
      ..lineTo(w * .64, h * .82)..lineTo(w * .36, h * .82)..close(), st);
    c.drawLine(Offset(w * .24, h * .26), Offset(w * .76, h * .26), st);
    c.drawPath(Path()
      ..moveTo(w * .31, h * .46)..lineTo(w * .69, h * .46)
      ..lineTo(w * .645, h * .79)..lineTo(w * .355, h * .79)..close(), fi);
    c.drawLine(Offset(w * .56, h * .26), Offset(w * .62, h * .12), st);
  }),
  IconGlyph('stack', 'Pilha de caixas', (c, s, st, fi) {
    final w = s.width, h = s.height;
    void box(double x, double y, double bw, double bh) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, bw, bh), Radius.circular(w * .03)), st);
      c.drawLine(Offset(x + bw / 2, y), Offset(x + bw / 2, y + bh * .35), st);
    }
    box(w * .16, h * .52, w * .32, h * .28);
    box(w * .52, h * .52, w * .32, h * .28);
    box(w * .34, h * .2, w * .32, h * .28);
  }),
  IconGlyph('barcode', 'Código de barras', (c, s, st, fi) {
    final w = s.width, h = s.height;
    const widths = [2.0, 1.0, 1.0, 3.0, 1.0, 2.0, 1.0, 1.0, 3.0, 1.0, 2.0];
    final unit = w * .6 / widths.fold<double>(0, (a, b) => a + b + 1);
    var x = w * .2;
    for (var i = 0; i < widths.length; i++) {
      c.drawRect(Rect.fromLTWH(x, h * .26, widths[i] * unit, h * .4), fi);
      x += (widths[i] + 1) * unit;
    }
    c.drawLine(Offset(w * .2, h * .76), Offset(w * .8, h * .76), st);
  }),
  IconGlyph('qr', 'QR Code', (c, s, st, fi) {
    final w = s.width, m = w * .2, cell = w * .6 / 7;
    void finder(double x, double y) {
      c.drawRect(Rect.fromLTWH(x, y, cell * 3, cell * 3), st);
      c.drawRect(Rect.fromLTWH(x + cell * .9, y + cell * .9, cell * 1.2, cell * 1.2), fi);
    }
    finder(m, m);
    finder(m + cell * 4, m);
    finder(m, m + cell * 4);
    for (final (cx, cy) in [(4, 4), (5, 5), (6, 4), (4, 6), (6, 6), (5, 3)]) {
      c.drawRect(Rect.fromLTWH(m + cx * cell, m + cy * cell, cell * .9, cell * .9), fi);
    }
  }),
  IconGlyph('truck', 'Caminhão', (c, s, st, fi) {
    final w = s.width, h = s.height;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(w * .12, h * .3, w * .6, h * .66), Radius.circular(w * .03)), st);
    c.drawPath(Path()
      ..moveTo(w * .6, h * .4)..lineTo(w * .76, h * .4)..lineTo(w * .88, h * .54)
      ..lineTo(w * .88, h * .66)..lineTo(w * .6, h * .66), st);
    c.drawCircle(Offset(w * .28, h * .7), w * .07, fi);
    c.drawCircle(Offset(w * .74, h * .7), w * .07, fi);
  }),
  IconGlyph('clipboard', 'Conferência', (c, s, st, fi) {
    final w = s.width, h = s.height;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(w * .24, h * .2, w * .76, h * .84), Radius.circular(w * .05)), st);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(w * .38, h * .14, w * .62, h * .26), Radius.circular(w * .03)), fi);
    for (var i = 0; i < 3; i++) {
      final y = h * (.42 + i * .13);
      c.drawPath(Path()
        ..moveTo(w * .32, y)..lineTo(w * .36, y + h * .04)..lineTo(w * .43, y - h * .04), st);
      c.drawLine(Offset(w * .5, y), Offset(w * .68, y), st);
    }
  }),
  IconGlyph('warehouse', 'Galpão', (c, s, st, fi) {
    final w = s.width, h = s.height;
    c.drawPath(Path()
      ..moveTo(w * .14, h * .44)..lineTo(w * .5, h * .2)..lineTo(w * .86, h * .44)
      ..lineTo(w * .86, h * .8)..lineTo(w * .14, h * .8)..close(), st);
    c.drawRect(Rect.fromLTRB(w * .34, h * .52, w * .66, h * .8), st);
    for (var i = 0; i < 3; i++) {
      c.drawLine(Offset(w * .34, h * (.6 + i * .07)), Offset(w * .66, h * (.6 + i * .07)), st);
    }
  }),
  IconGlyph('tag', 'Etiqueta', (c, s, st, fi) {
    final w = s.width, h = s.height;
    c.drawPath(Path()
      ..moveTo(w * .5, h * .16)..lineTo(w * .84, h * .16)..lineTo(w * .84, h * .5)
      ..lineTo(w * .46, h * .88)..lineTo(w * .12, h * .54)..close(), st);
    c.drawCircle(Offset(w * .7, h * .3), w * .06, fi);
  }),
  IconGlyph('chart', 'Gráfico', (c, s, st, fi) {
    final w = s.width, h = s.height;
    c.drawLine(Offset(w * .18, h * .16), Offset(w * .18, h * .82), st);
    c.drawLine(Offset(w * .18, h * .82), Offset(w * .86, h * .82), st);
    c.drawPath(Path()
      ..moveTo(w * .26, h * .66)..lineTo(w * .44, h * .48)..lineTo(w * .58, h * .58)..lineTo(w * .82, h * .28), st);
    c.drawCircle(Offset(w * .82, h * .28), w * .05, fi);
  }),
  IconGlyph('pallet', 'Palete', (c, s, st, fi) {
    final w = s.width, h = s.height;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(w * .22, h * .18, w * .78, h * .6), Radius.circular(w * .03)), st);
    c.drawLine(Offset(w * .22, h * .39), Offset(w * .78, h * .39), st);
    c.drawLine(Offset(w * .14, h * .68), Offset(w * .86, h * .68), st);
    for (final x in [.18, .5, .82]) {
      c.drawRect(Rect.fromLTWH(w * (x - .04), h * .7, w * .08, h * .12), fi);
    }
  }),
];

IconGlyph glyphById(String id) => iconGlyphs.firstWhere((g) => g.id == id, orElse: () => iconGlyphs.first);

/// Escolha de ícone de uma pessoa.
class AppIconChoice {
  final IconKind kind;
  final String value; // id do desenho ou o emoji
  final String colorId;
  const AppIconChoice({required this.kind, required this.value, required this.colorId});

  static const fallback = AppIconChoice(kind: IconKind.glyph, value: 'box-bars', colorId: 'lagoon');

  Map<String, dynamic> toJson() => {'kind': kind.name, 'value': value, 'color': colorId};

  factory AppIconChoice.fromJson(Map<String, dynamic> j) => AppIconChoice(
        kind: j['kind'] == 'emoji' ? IconKind.emoji : IconKind.glyph,
        value: j['value'] as String? ?? 'box-bars',
        colorId: j['color'] as String? ?? 'lagoon',
      );

  AppIconChoice copyWith({IconKind? kind, String? value, String? colorId}) =>
      AppIconChoice(kind: kind ?? this.kind, value: value ?? this.value, colorId: colorId ?? this.colorId);
}

/// Desenha um ícone escolhido em qualquer tamanho.
class AppIconView extends StatelessWidget {
  final AppIconChoice choice;
  final double size;
  const AppIconView({super.key, required this.choice, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final color = iconColorById(choice.colorId);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: color.gradient,
        borderRadius: BorderRadius.circular(size * .24),
      ),
      alignment: Alignment.center,
      child: choice.kind == IconKind.emoji
          ? Text(choice.value, style: TextStyle(fontSize: size * .56, height: 1.1))
          : CustomPaint(size: Size.square(size), painter: _GlyphPainter(glyphById(choice.value))),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final IconGlyph glyph;
  _GlyphPainter(this.glyph);

  @override
  void paint(Canvas canvas, Size s) {
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, s.width * .052)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    glyph.paint(canvas, s, stroke, fill);
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) => old.glyph.id != glyph.id;
}
