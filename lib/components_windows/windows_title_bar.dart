/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class WindowsTitleBar extends StatelessWidget {
  static const _bg = Color(0xFF1a1a2e);
  static const _cyan = Color(0xFF00C9E8);
  static const _purple = Color(0xFF7B68EE);

  final String title;
  final Widget? leading;
  final List<Widget>? actions;

  const WindowsTitleBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onPanStart: (_) => windowManager.startDragging(),
    child: Container(
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _bg,
            Color(0xFF16213e),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _cyan.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFE0E0E0),
                  letterSpacing: 0.5,
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
        color: _cyan,
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
        color: _purple,
      ),
      _WindowButton(
        icon: Icons.close,
        onPressed: () => windowManager.close(),
        isClose: true,
        color: Colors.red.shade400,
      ),
    ],
  );
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final VoidCallback onPressed;
  final bool isClose;
  final Color color;

  const _WindowButton({
    required this.icon,
    this.iconSize = 16,
    required this.onPressed,
    this.isClose = false,
    required this.color,
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
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: WindowsTitleBar._bg,
          borderRadius: BorderRadius.circular(8),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: widget.color.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: widget.color.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: Offset(2, 2),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.05),
                    blurRadius: 4,
                    offset: Offset(-2, -2),
                  ),
                ],
        ),
        child: Center(
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: _isHovered
                ? widget.color
                : Colors.grey.shade400,
          ),
        ),
      ),
    ),
  );
}
