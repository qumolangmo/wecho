/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class GlobalGainCard extends StatelessWidget {
  static const _bg = Color(0xFF16213e);
  static const _cardBg = Color(0xFF16213e);
  static const _cardBgLight = Color(0xFF1e2d4a);
  static const _cyan = Color(0xFF00C9E8);
  static const _purple = Color(0xFF7B68EE);
  static const _titleColor = Color(0xFFE0E0E0);
  static const double _cardWidth = 320.0;

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

  List<BoxShadow> _shadow() => [
    BoxShadow(color: Color(0xFF0a1018).withOpacity(0.6), offset: const Offset(4, 4), blurRadius: 8, spreadRadius: 1),
    BoxShadow(color: Color(0xFF4a5d7c).withOpacity(0.15), offset: const Offset(0, -1), blurRadius: 2, spreadRadius: 0),
    BoxShadow(color: Color(0xFF4a5d7c).withOpacity(0.1), offset: const Offset(-1, 0), blurRadius: 2, spreadRadius: 0),
  ];

  @override
  Widget build(BuildContext context) {
    final fraction = (value - min) / (max - min);
    
    return Container(
      width: _cardWidth,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cardBgLight, _cardBg],
        ),

        borderRadius: BorderRadius.circular(16),
        boxShadow: _shadow(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_cyan, _purple],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: _cyan.withOpacity(0.3), blurRadius: 8, spreadRadius: 1),
                    ],
                  ),
                  child: Center(
                    child: Icon(Icons.volume_up, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sliderWidth = constraints.maxWidth;
                final thumbSize = 20.0;
                final trackHeight = 12.0;
                final effectiveWidth = sliderWidth - thumbSize;
                final thumbLeft = fraction * effectiveWidth;
                
                return Container(
                  height: trackHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: trackHeight,
                        decoration: BoxDecoration(
                          color: Color(0xFF1e3a8a),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.3), offset: Offset(2, 2), blurRadius: 4),
                            BoxShadow(color: Colors.white.withOpacity(0.05), offset: Offset(-2, -2), blurRadius: 4),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 2,
                        bottom: 2,
                        width: thumbLeft + thumbSize / 2,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [_cyan, _purple],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(color: _cyan.withOpacity(0.4), blurRadius: 6, spreadRadius: 1),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: thumbLeft.clamp(0, effectiveWidth),
                        top: (trackHeight - thumbSize) / 2,
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
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [_cyan, _purple],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: _cyan.withOpacity(0.5), blurRadius: 8, spreadRadius: 1),
                                BoxShadow(color: Colors.black.withOpacity(0.3), offset: Offset(2, 2), blurRadius: 4),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
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
