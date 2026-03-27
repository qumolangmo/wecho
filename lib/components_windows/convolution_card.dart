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
  static const _bg = Color(0xFF16213e);
  static const _cardBg = Color(0xFF16213e);
  static const _cardBgLight = Color(0xFF1e2d4a);
  static const _cyan = Color(0xFF00C9E8);
  static const _purple = Color(0xFF7B68EE);
  static const _titleColor = Color(0xFFE0E0E0);
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

  List<BoxShadow> _shadow() => [
    BoxShadow(color: Color(0xFF0a1018).withOpacity(0.6), offset: const Offset(4, 4), blurRadius: 8, spreadRadius: 1),
    BoxShadow(color: Color(0xFF4a5d7c).withOpacity(0.15), offset: const Offset(0, -1), blurRadius: 2, spreadRadius: 0),
    BoxShadow(color: Color(0xFF4a5d7c).withOpacity(0.1), offset: const Offset(-1, 0), blurRadius: 2, spreadRadius: 0),
  ];

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
          _buildHeader(),
          if (expanded) ...[
            const SizedBox(height: 16),
            _buildFileSelector(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.all(8),
    child: Row(children: [
      GestureDetector(
        onTap: () {},
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
            child: Icon(Icons.waves, color: Colors.white, size: 20),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: enabled ? _titleColor : Colors.grey.shade400, height: 1.3)),
          Text(_displayFileName, style: TextStyle(fontSize: 14, color: enabled ? _cyan : Colors.grey.shade500, height: 1.3), overflow: TextOverflow.ellipsis, maxLines: 1),
        ],
      )),
      _buildSwitch(),
    ]),
  );

  Widget _buildFileSelector() => GestureDetector(
    onTap: enabled ? _pickFile : null,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Color(0xFF1e3a8a),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), offset: Offset(2, 2), blurRadius: 4),
          BoxShadow(color: Colors.white.withOpacity(0.05), offset: Offset(-2, -2), blurRadius: 4),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.folder_open, color: enabled ? _cyan : Colors.grey.shade500, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              filePath == null || filePath!.isEmpty ? '选择IR文件' : _displayFileName,
              style: TextStyle(fontSize: 13, color: enabled ? _titleColor : Colors.grey.shade500),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Icon(Icons.chevron_right, color: enabled ? _cyan : Colors.grey.shade500, size: 18),
        ],
      ),
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
}
