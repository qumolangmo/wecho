/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:flutter/material.dart';
import 'package:wecho/l10n/app_localizations.dart';

class MultiSliderControlCard extends StatelessWidget {
  static const _bg = Color(0xFFEEF2F7);
  static const _cardBg = Color(0xFFF0F4F8);
  static const _cyan = Color(0xFF00C9E8);
  static const _purple = Color(0xFF7B68EE);
  static const _titleColor = Color(0xFF334155);
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



  List<BoxShadow> _shadow({double offset = 6, double blur = 16}) => [
    BoxShadow(color: Colors.white.withOpacity(0.9), offset: const Offset(-4, -4), blurRadius: blur, spreadRadius: 1),
    BoxShadow(color: Colors.white.withOpacity(0.9), offset: const Offset(4, -4), blurRadius: blur, spreadRadius: 1),
    BoxShadow(color: Colors.black.withOpacity(0.1), offset: const Offset(4, 4), blurRadius: blur, spreadRadius: 1),
    BoxShadow(color: Colors.black.withOpacity(0.1), offset: const Offset(-4, 4), blurRadius: blur, spreadRadius: 1),
  ];

  List<BoxShadow> _smallShadow(bool active) => active
      ? [BoxShadow(color: Colors.white.withOpacity(0.9), offset: const Offset(-2, -2), blurRadius: 8, spreadRadius: 1),
         BoxShadow(color: Colors.white.withOpacity(0.9), offset: const Offset(2, -2), blurRadius: 8, spreadRadius: 1),
         BoxShadow(color: Colors.black.withOpacity(0.08), offset: const Offset(2, 2), blurRadius: 8, spreadRadius: 1),
         BoxShadow(color: Colors.black.withOpacity(0.08), offset: const Offset(-2, 2), blurRadius: 8, spreadRadius: 1)]
      : [BoxShadow(color: Colors.black.withOpacity(0.06), offset: const Offset(2, 2), blurRadius: 4, spreadRadius: 1),
         BoxShadow(color: Colors.black.withOpacity(0.06), offset: const Offset(-2, 2), blurRadius: 4, spreadRadius: 1),
         BoxShadow(color: Colors.white.withOpacity(0.7), offset: const Offset(-2, -2), blurRadius: 4, spreadRadius: 1),
         BoxShadow(color: Colors.white.withOpacity(0.7), offset: const Offset(2, -2), blurRadius: 4, spreadRadius: 1)];

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeInOut,
    width: _cardWidth,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: _cardBg,
      borderRadius: BorderRadius.circular(20),
      boxShadow: _shadow(),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [_buildHeader(context), if (expanded) _buildSlidersSection()],
    ),
  );

  Widget _buildHeader(BuildContext context) => InkWell(
    onTap: onToggleExpand,
    borderRadius: BorderRadius.vertical(top: const Radius.circular(20), bottom: expanded ? Radius.zero : const Radius.circular(20)),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        GestureDetector(
          onTap: () => _showDescriptionDialog(context),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), boxShadow: _smallShadow(enabled)),
            child: Icon(icon, color: enabled ? _cyan : Colors.grey.shade500, size: 24),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: enabled ? _titleColor : Colors.grey.shade600, height: 1.3)),
            Text(sliders.isNotEmpty ? sliders.first.valueText : '', style: TextStyle(fontSize: 14, color: enabled ? _cyan : Colors.grey.shade500, height: 1.3)),
          ],
        )),
        _buildSwitch(),
        const SizedBox(width: 8),
        AnimatedRotation(turns: expanded ? 0.5 : 0, duration: const Duration(milliseconds: 200),
          child: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade500, size: 28)),
      ]),
    ),
  );

  Widget _buildSwitch() => GestureDetector(
    onTap: () => onToggle(!enabled),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 56, height: 32,
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16), boxShadow: _shadow(offset: 3, blur: 6)),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 26, height: 26, margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: enabled ? _cyan : Colors.grey.shade400,
            shape: BoxShape.circle,
            boxShadow: enabled
                ? [BoxShadow(color: _cyan.withOpacity(0.4), offset: const Offset(0, 2), blurRadius: 8, spreadRadius: 2)]
                : [BoxShadow(color: Colors.black.withOpacity(0.08), offset: const Offset(0, 2), blurRadius: 4)],
          ),
        ),
      ),
    ),
  );

  void _showDescriptionDialog(BuildContext context) => showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(20), boxShadow: _shadow(offset: 8, blur: 20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10), boxShadow: _smallShadow(true)),
                child: Icon(icon, color: _cyan, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _titleColor)),
            ]),
            const SizedBox(height: 16),
            Text(description, style: TextStyle(fontSize: 14, height: 1.6, color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12), boxShadow: _smallShadow(true)),
                child: Text(AppLocalizations.of(context)!.close, style: TextStyle(color: _cyan, fontWeight: FontWeight.w500)),
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
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
        final trackHeight = 20.0;
        final effectiveWidth = constraints.maxWidth - thumbSize;
        final thumbLeft = fraction * effectiveWidth;
        
        return Container(
          height: trackHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: trackHeight,
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _shadow(offset: 3, blur: 6),
                ),
              ),
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
                      color: _bg,
                      shape: BoxShape.circle,
                      boxShadow: _shadow(offset: 2, blur: 4),
                    ),
                    child: Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: enabled ? _cyan : Colors.grey.shade400,
                          shape: BoxShape.circle,
                          boxShadow: enabled ? [BoxShadow(color: _cyan.withOpacity(0.5), blurRadius: 6, spreadRadius: 1)] : null,
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
