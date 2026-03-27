/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:flutter/material.dart';
import 'package:wecho/l10n/app_localizations.dart';

class MultiSliderControlCard extends StatelessWidget {
  static const _bg = Color(0xFF16213e);
  static const _cardBg = Color(0xFF16213e);
  static const _cardBgLight = Color(0xFF1e2d4a);
  static const _cyan = Color(0xFF00C9E8);
  static const _purple = Color(0xFF7B68EE);
  static const _titleColor = Color(0xFFE0E0E0);
  static const double _cardWidth = 320.0;
  static const double _sliderItemHeight = 70.0;

  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<bool> onToggle;
  final List<SliderConfig> sliders;

  const MultiSliderControlCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.enabled,
    required this.expanded,
    required this.onToggleExpand,
    required this.onToggle,
    required this.sliders,
  });



  List<BoxShadow> _shadow() => [
    // 主投影 - 右下
    BoxShadow(color: Color(0xFF0a1018).withOpacity(0.6), offset: const Offset(4, 4), blurRadius: 8, spreadRadius: 1),
    // 顶部白色晕
    BoxShadow(color: Color(0xFF4a5d7c).withOpacity(0.15), offset: const Offset(0, -1), blurRadius: 2, spreadRadius: 0),
    // 左侧白色晕
    BoxShadow(color: Color(0xFF4a5d7c).withOpacity(0.1), offset: const Offset(-1, 0), blurRadius: 2, spreadRadius: 0),
  ];

  List<BoxShadow> _smallShadow(bool active) => active
      ? [
          BoxShadow(color: Colors.black.withOpacity(0.3), offset: const Offset(2, 2), blurRadius: 4, spreadRadius: 1),
          BoxShadow(color: Colors.white.withOpacity(0.05), offset: const Offset(-2, -2), blurRadius: 4, spreadRadius: 1),
        ]
      : [
          BoxShadow(color: Colors.black.withOpacity(0.2), offset: const Offset(2, 2), blurRadius: 4, spreadRadius: 1),
          BoxShadow(color: Colors.white.withOpacity(0.03), offset: const Offset(-2, -2), blurRadius: 4, spreadRadius: 1),
        ];

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeInOut,
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
      children: [_buildHeader(context), if (expanded) _buildSlidersSection()],
    ),
  );

  Widget _buildHeader(BuildContext context) => InkWell(
    onTap: onToggleExpand,
    borderRadius: BorderRadius.vertical(top: const Radius.circular(16), bottom: expanded ? Radius.zero : const Radius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Row(children: [
        GestureDetector(
          onTap: () => _showDescriptionDialog(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: enabled ? [_cyan, _purple] : [Colors.grey.shade600, Colors.grey.shade800],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: enabled ? _cyan.withOpacity(0.3) : Colors.grey.shade700.withOpacity(0.3), blurRadius: 8, spreadRadius: 1),
              ],
            ),
            child: Center(
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: enabled ? _titleColor : Colors.grey.shade400, height: 1.3)),
            Text(sliders.isNotEmpty ? sliders.first.valueText : '', style: TextStyle(fontSize: 14, color: enabled ? _cyan : Colors.grey.shade500, height: 1.3)),
          ],
        )),
        _buildSwitch(),
      ]),
    ),
  );

  Widget _buildSwitch() => GestureDetector(
    onTap: () => onToggle(!enabled),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 56, height: 32,
      decoration: BoxDecoration(
        color: Color(0xFF1e3a8a),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), offset: Offset(2, 2), blurRadius: 4),
          BoxShadow(color: Colors.white.withOpacity(0.05), offset: Offset(-2, -2), blurRadius: 4),
        ],
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 26, height: 26, margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: enabled ? [_cyan, _purple] : [Colors.grey.shade600, Colors.grey.shade800],
            ),
            shape: BoxShape.circle,
            boxShadow: enabled
                ? [
                    BoxShadow(color: _cyan.withOpacity(0.4), offset: const Offset(0, 2), blurRadius: 8, spreadRadius: 2),
                    BoxShadow(color: Colors.black.withOpacity(0.3), offset: Offset(2, 2), blurRadius: 4),
                  ]
                : [
                    BoxShadow(color: Colors.black.withOpacity(0.3), offset: Offset(2, 2), blurRadius: 4),
                  ],
          ),
        ),
      ),
    ),
  );

  void _showDescriptionDialog(BuildContext context) => showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_cardBg, Color(0xFF0f3460)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _shadow(),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_cyan, _purple],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: _cyan.withOpacity(0.3), blurRadius: 8, spreadRadius: 1),
                  ],
                ),
                child: Center(
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _titleColor)),
            ]),
            const SizedBox(height: 16),
            Text(description, style: TextStyle(fontSize: 14, height: 1.6, color: Colors.grey.shade400)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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
                child: Text(AppLocalizations.of(context)!.close, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildSlidersSection() => AnimatedOpacity(
    duration: const Duration(milliseconds: 200),
    opacity: expanded ? 1.0 : 0.0,
    child: expanded
        ? SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(children: sliders.map((s) => _buildSlider(s)).toList()),
          )
        : const SizedBox.shrink(),
  );

  Widget _buildSlider(SliderConfig slider) => Column(
    children: [
      if (slider.label.isNotEmpty) ...[
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(slider.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _titleColor, height: 1.4)),
          Text(slider.valueText, style: const TextStyle(fontSize: 14, color: _cyan, fontWeight: FontWeight.w500, height: 1.4)),
        ]),
        const SizedBox(height: 12),
      ],
      _buildNeumorphicSlider(slider),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(slider.minLabel, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, height: 1.2)),
          Text(slider.maxLabel, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, height: 1.2)),
        ]),
      ),
      const SizedBox(height: 16),
    ],
  );

  Widget _buildNeumorphicSlider(SliderConfig slider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fraction = (slider.value - slider.min) / (slider.max - slider.min);
        final thumbSize = 20.0;
        final trackHeight = 12.0;
        final effectiveWidth = constraints.maxWidth - thumbSize;
        final thumbLeft = fraction * effectiveWidth;
        
        return Container(
          height: trackHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 轨道背景
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
              // 进度条
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
              // 滑块
              Positioned(
                left: thumbLeft.clamp(0, effectiveWidth),
                top: (trackHeight - thumbSize) / 2,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (!enabled) return;
                    final box = context.findRenderObject() as RenderBox;
                    final local = box.globalToLocal(details.globalPosition);
                    final newFraction = ((local.dx - thumbSize / 2) / effectiveWidth).clamp(0.0, 1.0);
                    var newValue = slider.min + newFraction * (slider.max - slider.min);
                    if (slider.divisions != null && slider.divisions! > 0) {
                      final step = (slider.max - slider.min) / slider.divisions!;
                      newValue = (newValue / step).round() * step;
                    }
                    slider.onChanged(newValue.clamp(slider.min, slider.max));
                  },
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: enabled ? [_cyan, _purple] : [Colors.grey.shade600, Colors.grey.shade800],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: enabled
                          ? [
                              BoxShadow(color: _cyan.withOpacity(0.5), blurRadius: 8, spreadRadius: 1),
                              BoxShadow(color: Colors.black.withOpacity(0.3), offset: Offset(2, 2), blurRadius: 4),
                            ]
                          : [
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
    );
  }
}

class SliderConfig {
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final String minLabel;
  final String maxLabel;
  final int decimalPlaces;

  SliderConfig({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    this.divisions,
    required this.onChanged,
    String? minLabel,
    String? maxLabel,
    this.decimalPlaces = 2,
  })  : minLabel = minLabel ?? '$min$unit',
        maxLabel = maxLabel ?? '$max$unit';

  String get valueText => '${value.toStringAsFixed(decimalPlaces)}$unit';
}
