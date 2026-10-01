/*
 * Copyright (C) 2026 qumolangmo
 *
 * This file is part of Wecho.
 *
 * Wecho is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Wecho is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Wecho.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../l10n/app_localizations.dart';
import '../models/ai_assistant_manager.dart';
import '../models/custom_ui_manager.dart';
import '../styles/neumorphic_styles.dart';
import '../view_models/dsp_controller_view_model.dart';
import 'neumorphic_button.dart';
import 'settings_page.dart';

/* Full-page chat entry (settings page). The floating overlay shares the same
 * message components and the same conversation history.
 */
class AiAssistantPage extends StatefulWidget {
  final DSPControllerViewModel viewModel;

  const AiAssistantPage({super.key, required this.viewModel});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  Future<bool> _handleSend(String text) async {
    final l10n = AppLocalizations.of(context)!;
    if (!AiAssistantManager.isConfigured) {
      _showSnack(l10n.aiNotConfigured);
      return false;
    }
    try {
      await AiAssistantManager.sendMessage(widget.viewModel, text);
      return true;
    } catch (e) {
      if (mounted) {
        _showSnack('${l10n.aiRequestFailed}: $e');
      }
      return false;
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.aiAssistant),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: l10n.aiClearHistory,
            onPressed: () => AiAssistantManager.clearHistory(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _ChatMessages(viewModel: widget.viewModel),
          ),
          _ChatInputBar(onSend: _handleSend),
        ],
      ),
    );
  }
}

/* ---- in-app floating overlay -------------------------------------------- */

/* Draggable bubble + expandable chat panel, rendered inside the app window
 * only (above the native or scripted home, so the assistant stays reachable
 * even when a custom UI script misbehaves).
 *
 * Performance contract: the panel subtree is cached in [_panelChild] and
 * stays the identical widget instance across rebuilds, so keyboard
 * animation (viewInsets) and dragging only move the Positioned shell - the
 * message list, input bar and shadows are never rebuilt per frame.
 */
class AiAssistantOverlay extends StatefulWidget {
  final DSPControllerViewModel viewModel;

  const AiAssistantOverlay({super.key, required this.viewModel});

  @override
  State<AiAssistantOverlay> createState() => _AiAssistantOverlayState();
}

class _AiAssistantOverlayState extends State<AiAssistantOverlay> {
  static const double _bubbleSize = 52;
  static const double _edgeMargin = 16;

  bool _expanded = false;
  bool _anchorInitialized = false;
  Offset _anchor = Offset.zero;
  Widget? _panelChild;

  /* Panel dimensions derived from the window size. */
  static (double, double) panelSize(Size screen) {
    final width = math.min(400.0, screen.width - 2 * _edgeMargin);
    final height = (screen.height * 0.62).clamp(320.0, 560.0).toDouble();
    return (width, height);
  }

  Future<bool> _handleSend(String text) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (!AiAssistantManager.isConfigured) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.aiNotConfigured)));
      return false;
    }
    try {
      await AiAssistantManager.sendMessage(widget.viewModel, text);
      return true;
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('${l10n.aiRequestFailed}: $e')),
        );
      }
      return false;
    }
  }

  Size _availableBounds() {
    final screen = MediaQuery.sizeOf(context);
    return Size(screen.width, screen.height - MediaQuery.viewInsetsOf(context).bottom);
  }

  void _clampAnchor(Size available,
      {required double rightSpace, required double bottomSpace}) {
    final maxX = math.max(0.0, available.width - rightSpace);
    final maxY = math.max(0.0, available.height - bottomSpace);
    _anchor = Offset(
      _anchor.dx.clamp(0.0, maxX).toDouble(),
      _anchor.dy.clamp(0.0, maxY).toDouble(),
    );
  }

  /* Opens the settings page above the overlay (the panel stays open for
   * after the user comes back).
   */
  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) =>
            SettingsPage(viewModel: widget.viewModel)));
  }

  void _onDrag(Offset delta) {
    setState(() {
      _anchor += delta;
      final (panelWidth, panelHeight) = panelSize(MediaQuery.sizeOf(context));
      _clampAnchor(_availableBounds(),
          rightSpace: panelWidth, bottomSpace: panelHeight);
    });
  }

  @override
  Widget build(BuildContext context) {
    /* sizeOf avoids rebuilding on unrelated MediaQuery changes. */
    final screen = MediaQuery.sizeOf(context);
    if (!_anchorInitialized) {
      _anchor = Offset(screen.width - _bubbleSize - _edgeMargin,
          screen.height * 0.65);
      _anchorInitialized = true;
    }

    return _expanded
        ? _buildPanel(screen)
        : _buildBubble(screen);
  }

  Widget _buildBubble(Size screen) {
    if (_anchorInitialized) {
      _clampAnchor(_availableBounds(),
          rightSpace: _bubbleSize, bottomSpace: _bubbleSize);
    }
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      left: _anchor.dx,
      top: _anchor.dy,
      child: GestureDetector(
        onTap: () => setState(() => _expanded = true),
        onPanUpdate: (details) {
          setState(() {
            _anchor += details.delta;
            _clampAnchor(_availableBounds(),
                rightSpace: _bubbleSize, bottomSpace: _bubbleSize);
          });
        },
        child: Container(
          width: _bubbleSize,
          height: _bubbleSize,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            shape: BoxShape.circle,
            boxShadow:
                NeumorphicStyles.activeIconBoxShadow(colorScheme.surface),
          ),
          child: Icon(Icons.auto_awesome, color: colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildPanel(Size screen) {
    final (panelWidth, panelHeight) = panelSize(screen);
    _clampAnchor(_availableBounds(),
        rightSpace: panelWidth, bottomSpace: panelHeight);
    /* Identical instance across rebuilds: keyboard animation and dragging
     * only reposition the shell below, the panel content is untouched.
     */
    _panelChild ??= _PanelBody(
      viewModel: widget.viewModel,
      onSend: _handleSend,
      onClose: () => setState(() => _expanded = false),
      onOpenSettings: _openSettings,
      onDrag: _onDrag,
    );

    return Positioned(
      left: _anchor.dx,
      top: _anchor.dy,
      child: SizedBox(
        width: panelWidth,
        height: panelHeight,
        child: _panelChild,
      ),
    );
  }
}

/* ---- panel body (cached instance, rebuilds only on theme change) --------- */

class _PanelBody extends StatelessWidget {
  final DSPControllerViewModel viewModel;
  final Future<bool> Function(String text) onSend;
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;
  final void Function(Offset delta) onDrag;

  const _PanelBody({
    required this.viewModel,
    required this.onSend,
    required this.onClose,
    required this.onOpenSettings,
    required this.onDrag,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(NeumorphicStyles.radiusXLarge),
        boxShadow: NeumorphicStyles.mainCardShadow(colorScheme.surface),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NeumorphicStyles.radiusXLarge),
        child: Material(
          /* The overlay lives outside any Scaffold; TextField requires a
           * Material ancestor.
           */
          type: MaterialType.transparency,
          child: Column(
            children: [
              /* Draggable title bar. */
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) => onDrag(details.delta),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: IconButton(
                          icon: Icon(Icons.settings_outlined,
                              size: 20, color: colorScheme.onSurfaceVariant),
                          onPressed: onOpenSettings,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          l10n.aiAssistant,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: IconButton(
                          icon: Icon(Icons.close,
                              size: 20, color: colorScheme.onSurfaceVariant),
                          onPressed: onClose,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: RepaintBoundary(
                  child: _ChatMessages(viewModel: viewModel),
                ),
              ),
              _ChatInputBar(onSend: onSend),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---- shared chat components ---------------------------------------------- */

class _ChatMessages extends StatelessWidget {
  final DSPControllerViewModel viewModel;

  const _ChatMessages({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.82;
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<bool>(
      valueListenable: AiAssistantManager.busy,
      builder: (context, busy, _) => ValueListenableBuilder<String?>(
        valueListenable: AiAssistantManager.streamingText,
        builder: (context, streaming, _) => ValueListenableBuilder<int>(
          valueListenable: AiAssistantManager.historyRevision,
          builder: (context, _, _) {
            /* The display list: user messages + pretty replies, without
             * the host result messages kept in the model context.
             */
            final history = AiAssistantManager.displayHistory;
            /* Tail slot: live token bubble once the first token arrives,
             * loading bubble before that.
             */
            final streamingContent =
                busy && streaming != null && streaming.isNotEmpty
                    ? streaming
                    : null;
            final hasTail = busy;
            final itemCount = history.length + (hasTail ? 1 : 0);

            if (itemCount == 0) {
              return Center(
                child: Text(
                  l10n.aiInputHint,
                  style: TextStyle(
                      fontSize: 14, color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              );
            }

            return ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                final reversed = itemCount - 1 - index;
                if (hasTail && reversed == history.length) {
                  if (streamingContent != null) {
                    return _MessageBubble(
                      message: {'role': 'assistant', 'content': streamingContent},
                      viewModel: viewModel,
                      maxWidth: maxWidth,
                      streaming: true,
                    );
                  }
                  return const _LoadingBubble();
                }
                return _MessageBubble(
                    message: history[reversed],
                    viewModel: viewModel,
                    maxWidth: maxWidth);
              },
            );
          },
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, String> message;
  final DSPControllerViewModel viewModel;
  final double maxWidth;

  /* True while the reply is still streaming in: apply buttons are hidden
   * because the code may be incomplete.
   */
  final bool streaming;

  const _MessageBubble({
    required this.message,
    required this.viewModel,
    required this.maxWidth,
    this.streaming = false,
  });

  Future<void> _applyCode(BuildContext context, String code, String lang) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (lang == 'dart') {
        await CustomUiManager.saveScriptSource(code);
        /* Feed the D4rt compile result back to Echo so a broken script can
         * be fixed in the next turn.
         */
        final err = CustomUiManager.lastError;
        AiAssistantManager.recordHostResult(err == null
            ? 'ui script applied successfully'
            : 'ui script FAILED to compile:\n$err');
        if (err != null) {
          messenger.showSnackBar(
            SnackBar(content: Text('${l10n.aiApplyFailed}: $err')),
          );
          return;
        }
      } else {
        final ok = await viewModel.saveScript(code);
        if (!ok) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.importFailedNoDesc)),
          );
          return;
        }
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.aiApplied)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${l10n.aiApplyFailed}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = message['role'] == 'user';
    final content = message['content'] ?? '';

    return Align(
      alignment:
          isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        constraints: BoxConstraints(maxWidth: maxWidth),
        /* Flat tinted bubble instead of a shadow: message bubbles are
         * repainted often and shadow blur is expensive.
         */
        decoration: BoxDecoration(
          color: isUser
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(NeumorphicStyles.radiusLarge),
        ),
        child: isUser
            ? Text(content,
                style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: colorScheme.onPrimary))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildSegments(context, content, colorScheme),
              ),
      ),
    );
  }

  List<Widget> _buildSegments(
      BuildContext context, String content, ColorScheme colorScheme) {
    final widgets = <Widget>[];
    final pattern = RegExp(r'```(\w*)[ \t]*\n?([\s\S]*?)```');
    var last = 0;
    for (final match in pattern.allMatches(content)) {
      if (match.start > last) {
        widgets.add(_buildText(context, content.substring(last, match.start), colorScheme));
      }
      final lang = (match.group(1) ?? '').toLowerCase();
      final code = (match.group(2) ?? '').trim();
      widgets.add(_buildCodeBlock(context, code, lang, colorScheme));
      last = match.end;
    }
    if (last < content.length) {
      widgets.add(_buildText(context, content.substring(last), colorScheme));
    }
    if (widgets.isEmpty) {
      widgets.add(_buildText(context, content, colorScheme));
    }
    return widgets;
  }

  Widget _buildText(BuildContext context, String text, ColorScheme colorScheme) {
    final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MarkdownBody(
        data: text.trim(),
        /* LLM replies use single newlines as visual breaks. */
        softLineBreak: true,
        styleSheet: base.copyWith(
          p: TextStyle(
              fontSize: 14, height: 1.5, color: colorScheme.onSurface),
          listBullet: TextStyle(
              fontSize: 14, height: 1.5, color: colorScheme.onSurface),
          blockquote: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: colorScheme.primary,
              fontWeight: FontWeight.w500),
          blockquoteDecoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.08),
            borderRadius:
                BorderRadius.circular(NeumorphicStyles.radiusSmall),
          ),
          code: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              backgroundColor: colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.12),
              color: colorScheme.onSurface),
        ),
      ),
    );
  }

  Widget _buildCodeBlock(
      BuildContext context, String code, String lang, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context)!;
    final isUiScript = lang == 'dart';
    final isDspScript = lang == 'c';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            code,
            style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontFamily: 'monospace',
                color: colorScheme.onSurface),
          ),
          if ((isUiScript || isDspScript) && !streaming) ...[
            const SizedBox(height: 8),
            NeumorphicButton(
              onTap: () => _applyCode(context, code, lang),
              padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              children: [
                Icon(Icons.download, size: 16, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  isUiScript ? l10n.aiApplyToUi : l10n.aiApplyToDsp,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.primary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadingBubble extends StatelessWidget {
  const _LoadingBubble();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(NeumorphicStyles.radiusLarge),
        ),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: colorScheme.primary),
        ),
      ),
    );
  }
}

class _ChatInputBar extends StatefulWidget {
  final Future<bool> Function(String text) onSend;

  const _ChatInputBar({required this.onSend});

  @override
  State<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<_ChatInputBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || AiAssistantManager.busy.value) return;
    _controller.clear();
    final ok = await widget.onSend(text);
    if (!ok) {
      /* Keep the user's message for retry. */
      _controller.text = text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: EdgeInsets.only(
          left: 16,
          right: 8,
          top: 8,
          bottom: 8 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: NeumorphicStyles.activeIconBoxShadow(colorScheme.surface),
      ),
      child: Row(
        children: [
          /* Isolates cursor-blink repaints from the shadowed bar. */
          Expanded(
            child: RepaintBoundary(
              child: TextField(
                controller: _controller,
                style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: l10n.aiInputHint,
                  hintStyle: TextStyle(
                      fontSize: 14, color: colorScheme.onSurfaceVariant),
                  border: InputBorder.none,
                ),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AiAssistantManager.busy,
            builder: (context, busy, _) => IconButton(
              icon: busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: colorScheme.primary),
                    )
                  : Icon(Icons.upload, color: colorScheme.primary),
              onPressed: busy ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }
}
