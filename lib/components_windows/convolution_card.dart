/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../l10n/app_localizations.dart';

class ConvolutionCard extends StatelessWidget {
  static const _bg = Color(0xFFEEF2F7);
  static const _cardBg = Color(0xFFF0F4F8);
  static const _cyan = Color(0xFF00C9E8);
  static const _titleColor = Color(0xFF334155);
  static const double _cardWidth = 320.0;

  final String title;
  final String description;
  final double mix;
  final String? filePath;
  final bool enabled;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onMixChanged;
  final ValueChanged<String> onFileSelected;

  const ConvolutionCard({
    super.key,
    required this.title,
    required this.description,
    required this.mix,
    this.filePath,
    required this.enabled,
    required this.expanded,
    required this.onToggleExpand,
    required this.onToggle,
    required this.onMixChanged,
    required this.onFileSelected,
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

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      onFileSelected(result.files.single.path!);
    }
  }

  String get _displayFileName {
    if (filePath == null || filePath!.isEmpty) return '未选择文件';
    final parts = filePath!.split(RegExp(r'[/\\]'));
    return parts.last;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _cardWidth,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _shadow(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          if (expanded) ...[
            const SizedBox(height: 16),
            _buildFileSelector(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() => InkWell(
    onTap: onToggleExpand,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), boxShadow: _smallShadow(enabled)),
            child: Icon(Icons.waves, color: enabled ? _cyan : Colors.grey.shade500, size: 24),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: enabled ? _titleColor : Colors.grey.shade600, height: 1.3)),
            Text(_displayFileName, style: TextStyle(fontSize: 14, color: enabled ? _cyan : Colors.grey.shade500, height: 1.3), overflow: TextOverflow.ellipsis, maxLines: 1),
          ],
        )),
        _buildSwitch(),
        const SizedBox(width: 8),
        AnimatedRotation(turns: expanded ? 0.5 : 0, duration: const Duration(milliseconds: 200),
          child: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade500, size: 28)),
      ]),
    ),
  );

  Widget _buildFileSelector() => GestureDetector(
    onTap: enabled ? _pickFile : null,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), boxShadow: _smallShadow(true)),
      child: Row(
        children: [
          Icon(Icons.folder_open, color: enabled ? _cyan : Colors.grey.shade500, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              filePath == null || filePath!.isEmpty ? '选择IR文件' : _displayFileName,
              style: TextStyle(fontSize: 14, color: enabled ? _titleColor : Colors.grey.shade500),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Icon(Icons.chevron_right, color: enabled ? _cyan : Colors.grey.shade500, size: 20),
        ],
      ),
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
}
