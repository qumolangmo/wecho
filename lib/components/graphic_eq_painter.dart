/// Copyright (C) 2026 qumolangmo
///
/// This file is part of Wecho.
///
/// Wecho is free software: you can redistribute it and/or modify
/// it under the terms of the GNU General Public License as published by
/// the Free Software Foundation, either version 3 of the License, or
/// (at your option) any later version.
///
/// Wecho is distributed in the hope that it will be useful,
/// but WITHOUT ANY WARRANTY; without even the implied warranty of
/// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
/// GNU General Public License for more details.
///
/// You should have received a copy of the GNU General Public License
/// along with Wecho.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:math' as math;
import 'package:flutter/material.dart';

class GraphicEqPainter extends CustomPainter {
  final List<double> responseDb;
  final int freqCount;
  final double dbMin;
  final double dbMax;

  final Color gridColor;
  final Color curveColor;
  final Color textColor;

  static const double leftPad = 24;
  static const double topPad = 12;
  static const double rightPad = 6;
  static const double bottomPad = 18;

  static final Map<String, TextPainter> _labelCache = {};

  TextPainter _cachedLabel(String text, Color color) {
    return _labelCache.putIfAbsent('$text|${color.toString()}', () {
      return TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: color, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  GraphicEqPainter({
    required this.responseDb,
    required this.freqCount,
    this.dbMin = -18,
    this.dbMax = 18,
    this.gridColor = const Color(0x33FFFFFF),
    this.curveColor = const Color(0xFF4FC3F7),
    this.textColor = const Color(0xAAFFFFFF),
  });

  double _dbToY(double db, double plotH) {
    final t = (db - dbMin) / (dbMax - dbMin);
    return topPad + plotH - t * plotH;
  }

  double _indexToX(int i, double plotW) {
    if (freqCount <= 1) return leftPad;
    return leftPad + i / (freqCount - 1) * plotW;
  }

  String _freqLabel(double f) {
    if (f >= 1000) {
      final k = f / 1000;
      return k == k.roundToDouble() ? '${k.round()}k' : '${k.toStringAsFixed(1)}k';
    }
    return '${f.round()}';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Plot area (inside the axis padding).
    final plotW = w - leftPad - rightPad;
    final plotH = h - topPad - bottomPad;
    final plotLeft = leftPad;
    final plotRight = leftPad + plotW;
    final plotTop = topPad;
    final plotBottom = topPad + plotH;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    // Horizontal dB grid lines every 6 dB + labels on the left.
    for (var db = dbMin; db <= dbMax + 0.01; db += 6) {
      final y = _dbToY(db, plotH);
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);
      final tp = _cachedLabel('${db.round()}', textColor);
      // Right-aligned in the left padding gutter.
      tp.paint(canvas, Offset(plotLeft - tp.width - 3, y - tp.height / 2));
    }
    // 0 dB emphasized.
    final zeroPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    final zy = _dbToY(0, plotH);
    canvas.drawLine(Offset(plotLeft, zy), Offset(plotRight, zy), zeroPaint);

    // Vertical grid at decade/octave markers + frequency labels.
    const fMin = 20.0, fMax = 20000.0;
    final logMin = math.log(fMin);
    final logMax = math.log(fMax);
    const freqMarks = [20.0, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000];
    final freqLabelY = plotBottom + 3;
    for (final f in freqMarks) {
      final t = (math.log(f) - logMin) / (logMax - logMin);
      final x = plotLeft + t * plotW;
      canvas.drawLine(Offset(x, plotTop), Offset(x, plotBottom), gridPaint);
      final tp = _cachedLabel(_freqLabel(f.toDouble()), textColor);
      // Clamp x so labels at the edges stay inside the canvas.
      final labelX = (x - tp.width / 2).clamp(0.0, w - tp.width);
      tp.paint(canvas, Offset(labelX, freqLabelY));
    }

    // Response curve.
    if (responseDb.length == freqCount) {
      final curvePath = Path();
      for (var i = 0; i < freqCount; i++) {
        final x = _indexToX(i, plotW);
        final y = _dbToY(responseDb[i].clamp(dbMin, dbMax), plotH);
        if (i == 0) {
          curvePath.moveTo(x, y);
        } else {
          curvePath.lineTo(x, y);
        }
      }
      canvas.drawPath(
        curvePath,
        Paint()
          ..color = curveColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GraphicEqPainter old) =>
      old.responseDb != responseDb ||
      old.dbMin != dbMin ||
      old.dbMax != dbMax;
}
