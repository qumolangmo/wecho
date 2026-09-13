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

/// Right pane of the Windows master-detail view: full parameter editor for
/// the selected effect — header (icon/title/description/enable switch) and
/// the schema children (sliders, enums, buttons, embedded panels).
class EffectDetailPane extends StatelessWidget {
  const EffectDetailPane({
    super.key,
    required this.viewModel,
    required this.spec,
  });

  final DSPControllerViewModel viewModel;

  /// One entry of [DSPControllerViewModel.effectCards].
  final List<dynamic> spec;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final renderer = EffectCardRenderer(viewModel);
    final enabledId = renderer.enabledIdOf(spec);
    final enabled = renderer.isEnabledOf(spec);
    final children = renderer.buildChildren(context, spec, l10n);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 24, 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: icon + title + enable switch.
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 16, 0),
            child: Row(
              children: [
                Icon(renderer.iconOf(spec), size: 22, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    renderer.titleOf(spec, l10n),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (enabledId != null)
                  Switch(
                    value: enabled,
                    onChanged: (v) => viewModel.update(enabledId, v),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
            child: Text(
              (spec[3] as Function)(l10n) as String,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
          ),
          Expanded(
            child: enabledId == null || enabled
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    children: children,
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.power_off_outlined,
                            size: 36, color: colorScheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text(
                          'Disabled',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
