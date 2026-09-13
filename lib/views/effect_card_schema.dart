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
import 'dart:ui' show clampDouble;

import '../components/components.dart';
import '../l10n/app_localizations.dart';
import '../models/audio_config.dart';
import '../view_models/dsp_controller_view_model.dart';

/// Platform-agnostic renderer for the effect card schema
/// ([DSPControllerViewModel.effectCards]). Shared by the Android
/// stack-scroll view and the Windows master-detail view.
class EffectCardRenderer {
  const EffectCardRenderer(this._viewModel);

  final DSPControllerViewModel _viewModel;

  // -- schema introspection --------------------------------------------------

  /// c[0]=expandKey, c[1]=icon, c[2]=title fn, c[3]=desc fn,
  /// c[4]=enabledId (null: no switch card), c[5]=sliders,
  /// c[6]=subtitle fn?, c[7]=leading schema fn?
  IconData iconOf(List<dynamic> c) => c[1] as IconData;

  String titleOf(List<dynamic> c, AppLocalizations l10n) =>
      (c[2] as Function)(l10n) as String;

  ParamID? enabledIdOf(List<dynamic> c) => c[4] as ParamID?;

  bool isEnabledOf(List<dynamic> c) {
    final id = enabledIdOf(c);
    return id == null ? true : _viewModel.get<bool>(id);
  }

  String subtitleOf(List<dynamic> c, AppLocalizations l10n) {
    final subtitle =
        c.length > 6 && c[6] != null ? (c[6] as Function)(_viewModel, l10n) as String : null;
    return subtitle ?? '';
  }

  // -- full card (Android stacked view) ---------------------------------------

  Widget buildCard(BuildContext context, List<dynamic> c, AppLocalizations l10n) {
    final expandKey = c[0] as String?;
    final enabledId = enabledIdOf(c);
    final sliders = c[5] as List;
    final enabled = isEnabledOf(c);
    final leading = c.length > 7 && c[7] != null
        ? ((c[7] as Function)(context, _viewModel) as List)
            .map((w) => buildSchemaWidget(w, enabled))
            .toList()
        : null;

    if (enabledId == null) {
      final s = sliders.single as List;
      final id = s[0] as ParamID;
      return ControlCard(
        icon: iconOf(c),
        title: titleOf(c, l10n),
        description: (c[3] as Function)(l10n) as String,
        value: clampDouble(_viewModel.get<num>(id).toDouble(), (s[2] as num).toDouble(), (s[3] as num).toDouble()),
        min: (s[2] as num).toDouble(),
        max: (s[3] as num).toDouble(),
        unit: s.length > 5 ? s[5] as String : '',
        expanded: _viewModel.isExpanded(expandKey!),
        onToggleExpand: () => _viewModel.toggleExpanded(expandKey),
        onChanged: (v) => _viewModel.update(id, v),
      );
    }

    return GenericControlCard(
      icon: iconOf(c),
      title: titleOf(c, l10n),
      subtitle: subtitleOf(c, l10n),
      description: (c[3] as Function)(l10n) as String,
      enabled: enabled,
      expanded: expandKey == null ? null : _viewModel.isExpanded(expandKey),
      onToggleExpand: expandKey == null ? null : () => _viewModel.toggleExpanded(expandKey),
      onToggle: (v) => _viewModel.update(enabledId, v),
      children: [
        ...?leading,
        for (final t in sliders) buildSlider(t, l10n, enabled),
      ],
    );
  }

  /// Detail-pane children (Windows): leading schema widgets + sliders,
  /// already wrapped with the card's enabled state.
  List<Widget> buildChildren(BuildContext context, List<dynamic> c, AppLocalizations l10n) {
    final enabled = isEnabledOf(c);
    final sliders = c[5] as List;
    final leading = c.length > 7 && c[7] != null
        ? ((c[7] as Function)(context, _viewModel) as List)
            .map((w) => buildSchemaWidget(w, enabled))
            .toList()
        : null;
    return [
      ...?leading,
      for (final t in sliders) buildSlider(t, l10n, enabled),
    ];
  }

  /// Resolves one widget-schema node (untyped tuple) or passes through an
  /// already-built widget. Supported nodes:
  /// - `['selector', [[value, label, deletable?]...], selected, onSelect, onDelete?, hint?]`
  /// - `['button', onTap, [children...], padding?]` (enabled follows the card switch)
  /// - `['row', [children...]]`, `['expanded', child]`
  /// - `['icon', iconData, color, size?]`, `['text', label, style?, ellipsis?]`
  /// - `['gap', size]` (vertical), `['hgap', size]` (horizontal)
  Widget buildSchemaWidget(dynamic w, bool enabled) {
    if (w is Widget) return w;
    final t = w as List;
    switch (t[0] as String) {
      case 'selector':
        return NeumorphicSelector<dynamic>(
          items: (t[1] as List)
              .map((it) => SelectorItem(
                    value: (it as List)[0],
                    label: it[1] as String,
                    deletable: it.length > 2 && it[2] == true,
                  ))
              .toList(),
          selectedValue: t[2],
          onSelect: t[3] as void Function(dynamic)?,
          onDelete: t.length > 4 ? t[4] as void Function(dynamic)? : null,
          enabled: enabled,
          hint: t.length > 5 ? t[5] as String : 'Select',
        );
      case 'button':
        return NeumorphicButton(
          onTap: t[1] as VoidCallback?,
          enabled: enabled,
          padding: t.length > 3
              ? t[3] as EdgeInsets
              : const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          children: [
            for (final c in t[2] as List) buildSchemaWidget(c, enabled),
          ],
        );
      case 'row':
        return Row(
          children: [
            for (final c in t[1] as List) buildSchemaWidget(c, enabled),
          ],
        );
      case 'expanded':
        return Expanded(child: buildSchemaWidget(t[1], enabled));
      case 'icon':
        return Icon(
          t[1] as IconData,
          color: t[2] as Color?,
          size: t.length > 3 ? (t[3] as num).toDouble() : 20,
        );
      case 'text':
        return Text(
          t[1] as String,
          style: t.length > 2 && t[2] != null ? t[2] as TextStyle : null,
          overflow: t.length > 3 && t[3] == true ? TextOverflow.ellipsis : null,
        );
      case 'gap':
        return SizedBox(height: (t[1] as num).toDouble());
      case 'hgap':
        return SizedBox(width: (t[1] as num).toDouble());
    }
    throw ArgumentError('Unknown widget schema node: $t');
  }

  /// Renders one slider from its untyped tuple
  /// `[id, label, min, max, divisions, unit?, isInt?, showDivider?]`.
  Widget buildSlider(List<dynamic> t, AppLocalizations l10n, bool enabled) {
    final id = t[0] as ParamID;
    final min = (t[2] as num).toDouble();
    final max = (t[3] as num).toDouble();
    return NeumorphicSlider(
      label: (t[1] as Function)(l10n) as String,
      value: clampDouble(_viewModel.get<num>(id).toDouble(), min, max),
      min: min,
      max: max,
      unit: t.length > 5 ? t[5] as String : '',
      divisions: t[4] as int,
      enabled: enabled,
      showDivider: t.length > 7 ? t[7] as bool : true,
      onChanged: (v) => t.length > 6 && t[6] == true
          ? _viewModel.update(id, v.toInt())
          : _viewModel.update(id, v),
    );
  }
}
