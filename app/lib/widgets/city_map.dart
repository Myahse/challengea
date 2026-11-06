import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Stylised city map (Marcory / Koumassi, Abidjan) drawn in code.
///
/// Prototype only: the web link cannot load real map tiles. In the installed
/// app this is replaced by a real map (flutter_map + OpenStreetMap, or Google
/// Maps) and friends' positions become real GPS coordinates.
class CityMapPainter extends CustomPainter {
  const CityMapPainter({this.focus, this.zoom = 1});

  /// Size of the whole map, in map pixels.
  static const world = Size(1400, 2000);

  /// When set, the painter shows only the area around [focus] (mini map).
  final Offset? focus;
  final double zoom;

  static const _night = ColorFilter.matrix([
    -1, 0, 0, 0, 255, //
    0, -1, 0, 0, 255, //
    0, 0, -1, 0, 255, //
    0, 0, 0, 1, 0, //
  ]);
  static const _ground = Color(0xFFF1F1EE);
  static const _roadEdge = Color(0xFFD9DCE1);
  static const _road = Colors.white;
  static const _park = Color(0xFFDDEFD9);
  static const _water = Color(0xFFAEDFF5);
  static const _highway = Color(0xFFA7B4C6);
  static const _highwayInner = Color(0xFFC4CEDB);
  static const _poiBlue = Color(0xFF1A73E8);
  static const _streetLabel = Color(0xFF6B7280);

  @override
  void paint(Canvas canvas, Size size) {
    // Night: the same map, inverted.
    if (AppColors.dark) {
      canvas.saveLayer(Offset.zero & size, Paint()..colorFilter = _night);
    } else {
      canvas.save();
    }
    canvas.clipRect(Offset.zero & size);
    if (focus != null) {
      canvas.translate(
        size.width / 2 - focus!.dx * zoom,
        size.height / 2 - focus!.dy * zoom,
      );
      canvas.scale(zoom);
    }
    canvas.drawRect(Offset.zero & world, Paint()..color = _ground);

    // Parks and the lagoon.
    final park = Paint()..color = _park;
    canvas.drawRRect(
      RRect.fromLTRBR(1080, 1600, 1330, 1780, const Radius.circular(18)),
      park,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(120, 420, 300, 560, const Radius.circular(18)),
      park,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(600, 820, 700, 900, const Radius.circular(40)),
      Paint()..color = const Color(0xFFFBEFD5),
    );
    final lagoon = Path()
      ..moveTo(0, 0)
      ..lineTo(520, 0)
      ..cubicTo(420, 90, 300, 130, 0, 170)
      ..close();
    canvas.drawPath(lagoon, Paint()..color = _water);

    // Street grid: two slightly tilted families, like Marcory's blocks.
    final edges = <(Offset, Offset)>[];
    final rnd = Random(7);
    final tiltA = tan(-4 * pi / 180), tiltB = tan(11 * pi / 180);
    for (var y = 260.0; y < 2200; y += 62 + rnd.nextInt(16)) {
      edges.add((Offset(-50, y), Offset(1450, y + 1500 * tiltA)));
    }
    for (var x = -420.0; x < 1500; x += 56 + rnd.nextInt(14)) {
      edges.add((Offset(x, 230), Offset(x + 1800 * tiltB, 2030)));
    }
    // A diagonal neighbourhood in the north-west.
    for (var k = 0; k < 9; k++) {
      final o = 160.0 + k * 52;
      edges.add((Offset(0, 240 + o), Offset(o + 240, 240)));
    }
    _strokeRoads(canvas, edges, 9, 6);

    // Main roads.
    final major = <(Offset, Offset)>[
      (const Offset(-50, 1160), const Offset(1450, 1055)), // Avenue Paul
      (const Offset(560, 230), const Offset(915, 2030)), // Avenue des Métiers
      (const Offset(-50, 1700), const Offset(560, 1460)), // Rue du 7 Décembre
      (const Offset(-50, 300), const Offset(1450, 200)),
    ];
    _strokeRoads(canvas, major, 18, 13);

    // Highway (bottom-left), drawn as in the Figma screenshot.
    final highway = Path()
      ..moveTo(-60, 1290)
      ..cubicTo(200, 1380, 380, 1560, 470, 2060);
    canvas.drawPath(
      highway,
      Paint()
        ..color = _highway
        ..style = PaintingStyle.stroke
        ..strokeWidth = 30,
    );
    canvas.drawPath(
      highway,
      Paint()
        ..color = _highwayInner
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20,
    );

    // Canal along the top.
    final canal = Path()
      ..moveTo(0, 215)
      ..cubicTo(400, 205, 900, 190, 1400, 150);
    canvas.drawPath(
      canal,
      Paint()
        ..color = _water
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12,
    );

    // Labels.
    _label(
      canvas,
      'Avenue des Métiers',
      const Offset(700, 1350),
      angle: 78.8,
      color: _streetLabel,
      size: 15,
    );
    _label(
      canvas,
      'Rue du 7 Décembre',
      const Offset(260, 1585),
      angle: -21.5,
      color: _streetLabel,
      size: 15,
    );
    _label(
      canvas,
      'Avenue Paul',
      const Offset(1150, 1080),
      angle: -4,
      color: _streetLabel,
      size: 14,
    );
    _label(
      canvas,
      'REMBLAIS',
      const Offset(1190, 520),
      color: _streetLabel,
      size: 16,
      weight: FontWeight.w700,
    );
    _label(
      canvas,
      'Lagune Ébrié',
      const Offset(190, 70),
      color: const Color(0xFF3B8DB5),
      size: 15,
    );
    _poi(
      canvas,
      'Grand Marché\nde Marcory',
      const Offset(150, 690),
      Icons.storefront,
      _poiBlue,
    );
    _poi(
      canvas,
      'Pharmacie',
      const Offset(860, 900),
      Icons.local_pharmacy,
      const Color(0xFFE5484D),
    );
    _poi(
      canvas,
      'Grand Carrefour\nde Koumassi',
      const Offset(560, 1790),
      Icons.shopping_bag,
      _poiBlue,
    );
    _poi(
      canvas,
      'Paroisse Saint-Jean',
      const Offset(1100, 1420),
      Icons.church,
      _streetLabel,
    );
    _poi(
      canvas,
      'Hôtel',
      const Offset(1250, 860),
      Icons.hotel,
      const Color(0xFFE546A8),
    );
    _poi(
      canvas,
      'Stade',
      const Offset(1200, 1690),
      Icons.sports_soccer,
      const Color(0xFF2E9E5B),
    );
    canvas.restore();
  }

  void _strokeRoads(
    Canvas canvas,
    List<(Offset, Offset)> roads,
    double outer,
    double inner,
  ) {
    final edge = Paint()
      ..color = _roadEdge
      ..strokeWidth = outer
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = _road
      ..strokeWidth = inner
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in roads) {
      canvas.drawLine(a, b, edge);
    }
    for (final (a, b) in roads) {
      canvas.drawLine(a, b, fill);
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at, {
    double angle = 0,
    required Color color,
    double size = 14,
    FontWeight weight = FontWeight.w500,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: size,
          color: color,
          fontWeight: weight,
          fontVariations: [FontVariation('wght', weight.value.toDouble())],
          letterSpacing: weight == FontWeight.w700 ? 2 : 0,
          shadows: const [Shadow(color: Colors.white, blurRadius: 3)],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle * pi / 180);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  void _poi(Canvas canvas, String text, Offset at, IconData icon, Color color) {
    canvas.drawCircle(at, 15, Paint()..color = color);
    final ip = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    ip.paint(canvas, at - Offset(ip.width / 2, ip.height / 2));
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 16,
          height: 1.1,
          color: color,
          fontVariations: const [FontVariation('wght', 500)],
          shadows: const [Shadow(color: Colors.white, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at + Offset(22, -tp.height / 2));
  }

  @override
  bool shouldRepaint(CityMapPainter old) =>
      old.focus != focus || old.zoom != zoom;
}
