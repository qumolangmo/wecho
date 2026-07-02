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

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'multi_slider_control_card.dart';
import 'neumorphic_description_dialog.dart';
import '../l10n/app_localizations.dart';

class ScriptEffectCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<bool> onToggle;
  final String activeScriptDesc;
  final Map<String, String> scriptLibrary;
  final ValueChanged<String> onScriptSelect;
  final ValueChanged<String> onScriptDelete;
  final VoidCallback onCodeEditorTap;
  final ValueChanged<String> onImportScript;
  final VoidCallback onExportScript;
  final List<SliderConfig> sliders;

  const ScriptEffectCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.enabled,
    required this.expanded,
    required this.onToggleExpand,
    required this.onToggle,
    required this.activeScriptDesc,
    required this.scriptLibrary,
    required this.onScriptSelect,
    required this.onScriptDelete,
    required this.onCodeEditorTap,
    required this.onImportScript,
    required this.onExportScript,
    required this.sliders,
  });

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
          BoxShadow(color: lightShadow, blurRadius: 15, offset: const Offset(-5, -5)),
          BoxShadow(color: darkShadow, blurRadius: 15, offset: const Offset(5, 5)),
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
        bottom: Radius.circular(expanded ? 0 : 20),
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
                          BoxShadow(color: lightShadow, blurRadius: 8, offset: const Offset(-3, -3)),
                          BoxShadow(color: darkShadow, blurRadius: 8, offset: const Offset(3, 3)),
                        ]
                      : [
                          BoxShadow(color: darkShadow, blurRadius: 6, offset: const Offset(2, 2)),
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
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (sliders.isNotEmpty)
                    Text(
                      sliders.first.valueText,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
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
    final baseColor = colorScheme.surface;
    final lightShadow = baseColor.withRed(255).withGreen(255).withBlue(255).withValues(alpha: enabled ? 0.7 : 0.4);
    final darkShadow = baseColor.withRed(0).withGreen(0).withBlue(0).withValues(alpha: enabled ? 0.15 : 0.08);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: expanded
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  // Script selector dropdown
                  _buildScriptSelector(context, colorScheme, baseColor, lightShadow, darkShadow),
                  const SizedBox(height: 12),
                  // Code editor button
                  _buildCodeEditorButton(context, colorScheme, baseColor, lightShadow, darkShadow),
                  const SizedBox(height: 12),
                  // Import / Export buttons
                  _buildImportExportButtons(context, colorScheme, baseColor, lightShadow, darkShadow),
                  const SizedBox(height: 12),
                  // Parameter sliders
                  ...sliders.map((slider) => _buildSlider(context, colorScheme, baseColor, lightShadow, darkShadow, slider)),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildScriptSelector(BuildContext context, ColorScheme colorScheme, Color baseColor, Color lightShadow, Color darkShadow) {
    final descs = scriptLibrary.keys.toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: darkShadow, blurRadius: 6, offset: const Offset(3, 3)),
          BoxShadow(color: lightShadow, blurRadius: 6, offset: const Offset(-3, -3)),
        ],
      ),
      child: DropdownButton<String>(
        value: activeScriptDesc.isNotEmpty && descs.contains(activeScriptDesc)
            ? activeScriptDesc : null,
        hint: Text('Select script', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
        isExpanded: true,
        underline: const SizedBox.shrink(),
        icon: Icon(Icons.arrow_drop_down, color: enabled ? colorScheme.primary : colorScheme.onSurfaceVariant),
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface),
        items: descs.map((desc) => DropdownMenuItem(
          value: desc,
          child: Row(
            children: [
              Expanded(child: Text(desc)),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop(); // close dropdown popup first
                  onScriptDelete(desc);
                },
                child: Icon(Icons.close, size: 16, color: colorScheme.error),
              ),
            ],
          ),
        )).toList(),
        onChanged: enabled ? (desc) {
          if (desc != null) onScriptSelect(desc);
        } : null,
      ),
    );
  }

  Widget _buildCodeEditorButton(BuildContext context, ColorScheme colorScheme, Color baseColor, Color lightShadow, Color darkShadow) {
    return GestureDetector(
      onTap: enabled ? onCodeEditorTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: darkShadow, blurRadius: 6, offset: const Offset(3, 3)),
            BoxShadow(color: lightShadow, blurRadius: 6, offset: const Offset(-3, -3)),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.code,
              color: enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.editScript,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: enabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Icon(
              Icons.edit,
              color: enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportExportButtons(BuildContext context, ColorScheme colorScheme, Color baseColor, Color lightShadow, Color darkShadow) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['c', 'h', 'txt'],
              );
              if (result != null && result.files.single.path != null) {
                final file = File(result.files.single.path!);
                final bytes = await file.readAsBytes();
                // Strip UTF-8 BOM if present
                var start = 0;
                if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
                  start = 3;
                }
                final data = bytes.sublist(start);
                // Try UTF-8 first, fall back to ASCII (latin-1)
                String code;
                try {
                  code = utf8.decode(data);
                } catch (_) {
                  code = latin1.decode(data);
                }
                if (code.isNotEmpty) {
                  onImportScript(code);
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: darkShadow, blurRadius: 6, offset: const Offset(3, 3)),
                  BoxShadow(color: lightShadow, blurRadius: 6, offset: const Offset(-3, -3)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.file_download, color: enabled ? colorScheme.primary : colorScheme.onSurfaceVariant, size: 18),
                  const SizedBox(width: 6),
                  Text(AppLocalizations.of(context)!.importScript, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: onExportScript,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: darkShadow, blurRadius: 6, offset: const Offset(3, 3)),
                  BoxShadow(color: lightShadow, blurRadius: 6, offset: const Offset(-3, -3)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.file_upload, color: enabled ? colorScheme.primary : colorScheme.onSurfaceVariant, size: 18),
                  const SizedBox(width: 6),
                  Text(AppLocalizations.of(context)!.exportScript, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlider(BuildContext context, ColorScheme colorScheme, Color baseColor, Color lightShadow, Color darkShadow, SliderConfig slider) {
    return Column(
      children: [
        if (slider.label.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                slider.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                slider.valueText,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: darkShadow, blurRadius: 6, offset: const Offset(3, 3)),
              BoxShadow(color: lightShadow, blurRadius: 6, offset: const Offset(-3, -3)),
            ],
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: colorScheme.primary,
              inactiveTrackColor: colorScheme.surfaceContainerHighest,
              thumbColor: colorScheme.primary,
              overlayColor: colorScheme.primary.withValues(alpha: 0.1),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: slider.value,
              min: slider.min,
              max: slider.max,
              divisions: slider.divisions,
              onChanged: enabled ? slider.onChanged : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                slider.minLabel,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              Text(
                slider.maxLabel,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
