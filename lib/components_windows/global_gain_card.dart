/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class GlobalGainCard extends StatelessWidget {
  static const _bg = Color(0xFFEEF2F7);
  static const _cardBg = Color(0xFFF0F4F8);
  static const _cyan = Color(0xFF00C9E8);
  static const _titleColor = Color(0xFF334155);
  static const double _cardWidth = 320.0;
  static const double _cardHeight = 100.0;

  final String title;
  final String description;
  final double value;
  final double min;
  final double max;
  final String unit;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<double> onChanged;

  const GlobalGainCard({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.expanded,
    required this.onToggleExpand,
    required this.onChanged,
  });

  List<BoxShadow> _shadow({double offset = 6, double blur = 16}) => [
    BoxShadow(color: Colors.white.withOpacity(0.9), offset: const Offset(-4, -4), blurRadius: blur, spreadRadius: 1),
    BoxShadow(color: Colors.white.withOpacity(0.9), offset: const Offset(4, -4), blurRadius: blur, spreadRadius: 1),
    BoxShadow(color: Colors.black.withOpacity(0.1), offset: const Offset(4, 4), blurRadius: blur, spreadRadius: 1),
    BoxShadow(color: Colors.black.withOpacity(0.1), offset: const Offset(-4, 4), blurRadius: blur, spreadRadius: 1),
  ];

  @override
  Widget build(BuildContext context) {
    final fraction = (value - min) / (max - min);
    
    return Container(
      width: _cardWidth,
      height: _cardHeight,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _shadow(),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _titleColor, height: 1.3)),
                    Text('${value.toStringAsFixed(1)}$unit', style: const TextStyle(fontSize: 14, color: _cyan, height: 1.3)),
                  ],
                ),
                Icon(Icons.volume_up, color: _cyan, size: 24),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final thumbSize = 20.0;
                final trackHeight = 20.0;
                final effectiveWidth = constraints.maxWidth - thumbSize;
                final thumbLeft = fraction * effectiveWidth;
                
                return Container(
                  height: trackHeight,
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _shadow(offset: 3, blur: 6),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 4,
                        top: 4,
                        bottom: 4,
                        width: thumbLeft + thumbSize / 2 - 4,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Color(0xFF00B4D8), Color(0xFF00C9E8)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      Positioned(
                        left: thumbLeft.clamp(0, effectiveWidth),
                        top: 0,
                        child: GestureDetector(
                          onHorizontalDragUpdate: (details) {
                            final box = context.findRenderObject() as RenderBox;
                            final local = box.globalToLocal(details.globalPosition);
                            final newFraction = ((local.dx - thumbSize / 2) / effectiveWidth).clamp(0.0, 1.0);
                            final newValue = min + newFraction * (max - min);
                            onChanged(newValue);
                          },
                          child: Container(
                            width: thumbSize,
                            height: thumbSize,
                            decoration: BoxDecoration(
                              color: _bg,
                              shape: BoxShape.circle,
                              boxShadow: _shadow(offset: 2, blur: 4),
                            ),
                            child: Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _cyan,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: _cyan.withOpacity(0.5), blurRadius: 6, spreadRadius: 1)],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
