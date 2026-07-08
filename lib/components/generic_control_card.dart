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
import 'package:wecho/components/neumorphic_description_dialog.dart';
import '../styles/neumorphic_styles.dart';

/// A neumorphic control card with an optional expandable section that hosts
/// arbitrary widgets.
///
/// When [onToggleExpand] is `null` the card operates in **non-expandable**
/// mode – only the header (icon + title + switch) is shown and no content
/// area is rendered.  When [onToggleExpand] is provided the card is
/// expandable, and [expanded] controls the visibility of [children].
class GenericControlCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final bool enabled;

  /// Whether the children section is visible.
  ///
  /// Only meaningful when [onToggleExpand] is non-null.
  /// Ignored when [onToggleExpand] is null (non-expandable mode).
  final bool? expanded;

  /// Callback to toggle the expanded state.
  ///
  /// When `null` the card is non-expandable – the header is not tappable
  /// for expand/collapse and the children section is never shown.
  final VoidCallback? onToggleExpand;

  final ValueChanged<bool> onToggle;
  final List<Widget> children;

  const GenericControlCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle = '',
    required this.description,
    required this.enabled,
    this.expanded,
    this.onToggleExpand,
    required this.onToggle,
    this.children = const [],
  });

  bool get _isExpandable => onToggleExpand != null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(NeumorphicStyles.radiusXLarge),
        boxShadow: NeumorphicStyles.conditionalMainCardShadow(baseColor, enabled),
      ),
      child: Column(
        children: [
          _buildHeader(context, colorScheme),
          if (_isExpandable) _buildChildrenSection(context, colorScheme),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    final baseColor = colorScheme.surface;

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
                  borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
                  boxShadow: NeumorphicStyles.conditionalIconBoxShadow(baseColor, enabled),
                ),
                child: Icon(
                  icon,
                  color: enabled
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
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
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
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

  Widget _buildChildrenSection(BuildContext context, ColorScheme colorScheme) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: expanded == true
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                children: children,
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
