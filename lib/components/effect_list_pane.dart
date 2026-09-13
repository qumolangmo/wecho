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

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../view_models/dsp_controller_view_model.dart';
import '../views/effect_card_schema.dart';

/// Left rail of the Windows master-detail view: one compact entry per effect
/// (icon + title + mini enable switch), the selected one highlighted.
class EffectListPane extends StatelessWidget {
  const EffectListPane({
    super.key,
    required this.viewModel,
    required this.selectedIndex,
    required this.onSelect,
  });

  final DSPControllerViewModel viewModel;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final renderer = EffectCardRenderer(viewModel);
    final specs = viewModel.effectCards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Master DSP switch row.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(Icons.power_settings_new,
                  size: 18, color: viewModel.masterEnabled ? colorScheme.primary : colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              const Spacer(),
              Switch(
                value: viewModel.masterEnabled,
                onChanged: (v) => viewModel.updateMasterEnabled(v),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            itemCount: specs.length,
            itemBuilder: (context, i) {
              final c = specs[i];
              final selected = i == selectedIndex;
              final enabledId = renderer.enabledIdOf(c);
              final enabled = renderer.isEnabledOf(c);
              final active = enabled && (enabledId == null || viewModel.masterEnabled);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Material(
                  color: selected ? colorScheme.secondaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelect(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? colorScheme.primary : Colors.transparent,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            renderer.iconOf(c),
                            size: 20,
                            color: active ? colorScheme.primary : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              renderer.titleOf(c, l10n),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                color: selected ? colorScheme.onSecondaryContainer : colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (enabledId != null)
                            Transform.scale(
                              scale: 0.68,
                              child: Switch(
                                value: enabled,
                                onChanged: (v) => viewModel.update(enabledId, v),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
