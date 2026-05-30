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
import 'package:window_manager/window_manager.dart';

class WindowsTitleBar extends StatelessWidget {
  static const _bg = Color(0xFFEEF2F7);
  static const _cardBg = Color(0xFFF0F4F8);
  static const _cyan = Color(0xFF00C9E8);
  static const _titleColor = Color(0xFF334155);

  final String title;
  final Widget? leading;
  final List<Widget>? actions;

  const WindowsTitleBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
  });

  List<BoxShadow> _shadow({double offset = 4, double blur = 8}) => [
    BoxShadow(color: Colors.white.withOpacity(0.9), offset: const Offset(-2, -2), blurRadius: blur, spreadRadius: 1),
    BoxShadow(color: Colors.white.withOpacity(0.9), offset: const Offset(2, -2), blurRadius: blur, spreadRadius: 1),
    BoxShadow(color: Colors.black.withOpacity(0.08), offset: const Offset(2, 2), blurRadius: blur, spreadRadius: 1),
    BoxShadow(color: Colors.black.withOpacity(0.08), offset: const Offset(-2, 2), blurRadius: blur, spreadRadius: 1),
  ];

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onPanStart: (_) => windowManager.startDragging(),
    child: Container(
      height: 32,
      color: _bg,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _titleColor,
                ),
              ),
            ),
          ),
          if (actions != null) ...actions!,
          _buildWindowButtons(),
        ],
      ),
    ),
  );

  Widget _buildWindowButtons() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _WindowButton(
        icon: Icons.remove,
        onPressed: () => windowManager.minimize(),
      ),
      _WindowButton(
        icon: Icons.crop_square,
        iconSize: 14,
        onPressed: () async {
          if (await windowManager.isMaximized()) {
            windowManager.unmaximize();
          } else {
            windowManager.maximize();
          }
        },
      ),
      _WindowButton(
        icon: Icons.close,
        onPressed: () => windowManager.close(),
        isClose: true,
      ),
    ],
  );
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final VoidCallback onPressed;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    this.iconSize = 16,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _isHovered = true),
    onExit: (_) => setState(() => _isHovered = false),
    child: GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 46,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: WindowsTitleBar._bg,
          borderRadius: BorderRadius.circular(6),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: (widget.isClose ? Colors.red : WindowsTitleBar._cyan).withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: _isHovered && widget.isClose
                ? Colors.red.shade400
                : Colors.grey.shade600,
          ),
        ),
      ),
    ),
  );
}
