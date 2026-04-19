/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:wecho/l10n/app_localizations.dart';
import 'package:wecho/components/neumorphic_description_dialog.dart';

class ConvolveControlCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final double mixValue;
  final double mixMin;
  final double mixMax;
  final String irPath;
  final bool enabled;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onMixChanged;
  final ValueChanged<String> onIrPathChanged;

  const ConvolveControlCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.mixValue,
    required this.mixMin,
    required this.mixMax,
    required this.irPath,
    required this.enabled,
    required this.expanded,
    required this.onToggleExpand,
    required this.onToggle,
    required this.onMixChanged,
    required this.onIrPathChanged,
  });

  Future<void> _pickFile(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: false,
        withReadStream: false,
      );

      if (result != null && result.files.single.path != null) {
        onIrPathChanged(result.files.single.path!);
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surface;
    final lightShadow = baseColor.withRed(255).withGreen(255).withBlue(255).withValues(alpha: enabled ? 0.7 : 0.4);
    final darkShadow = baseColor.withRed(0).withGreen(0).withBlue(0).withValues(alpha: enabled ? 0.15 : 0.08);

    return Container(
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: lightShadow,
            blurRadius: 15,
            offset: const Offset(-5, -5),
          ),
          BoxShadow(
            color: darkShadow,
            blurRadius: 15,
            offset: const Offset(5, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(context, colorScheme),
          _buildContent(context, colorScheme),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    final baseColor = colorScheme.surface;
    final lightShadow = baseColor.withRed(255).withGreen(255).withBlue(255).withValues(alpha: enabled ? 0.7 : 0.4);
    final darkShadow = baseColor.withRed(0).withGreen(0).withBlue(0).withValues(alpha: enabled ? 0.15 : 0.08);

    return InkWell(
      onTap: onToggleExpand,
      borderRadius: BorderRadius.vertical(
        top: const Radius.circular(20),
        bottom: const Radius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => NeumorphicDescriptionDialog.show(
                context: context,
                icon: icon,
                title: title,
                description: description,
              ),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: enabled
                      ? [
                          BoxShadow(
                            color: lightShadow,
                            blurRadius: 8,
                            offset: const Offset(-3, -3),
                          ),
                          BoxShadow(
                            color: darkShadow,
                            blurRadius: 8,
                            offset: const Offset(3, 3),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: darkShadow,
                            blurRadius: 6,
                            offset: const Offset(2, 2),
                          ),
                        ],
                ),
                child: Icon(
                  icon,
                  color: enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: enabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: enabled,
              onChanged: onToggle,
              activeThumbColor: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme colorScheme) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: expanded
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Opacity(
                opacity: enabled ? 1.0 : 0.3,
                child: IgnorePointer(
                  ignoring: !enabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFilePicker(context, colorScheme),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildFilePicker(BuildContext context, ColorScheme colorScheme) {
    final baseColor = colorScheme.surface;
    final lightShadow = baseColor.withRed(255).withGreen(255).withBlue(255).withValues(alpha: enabled ? 0.7 : 0.4);
    final darkShadow = baseColor.withRed(0).withGreen(0).withBlue(0).withValues(alpha: enabled ? 0.15 : 0.08);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.irFile,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _pickFile(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: darkShadow,
                  blurRadius: 6,
                  offset: const Offset(3, 3),
                ),
                BoxShadow(
                  color: lightShadow,
                  blurRadius: 6,
                  offset: const Offset(-3, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.audio_file,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    irPath.isEmpty ? AppLocalizations.of(context)!.selectIRFile : irPath.split('/').last,
                    style: TextStyle(
                      fontSize: 14,
                      color: irPath.isEmpty
                          ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                          : colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.folder_open,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
