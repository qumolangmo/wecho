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
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:highlight/languages/cpp.dart';
import '../l10n/app_localizations.dart';

class ScriptEditorPage extends StatefulWidget {
  final String initialCode;
  final ValueChanged<String> onSave;

  const ScriptEditorPage({super.key, required this.initialCode, required this.onSave});

  @override
  State<ScriptEditorPage> createState() => _ScriptEditorPageState();
}

class _ScriptEditorPageState extends State<ScriptEditorPage> {
  late CodeController _controller;
  bool _isDark = true;

  @override
  void initState() {
    super.initState();
    _controller = CodeController(
      text: widget.initialCode,
      language: cpp,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(_controller.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    _isDark = brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.editScript),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: MaterialLocalizations.of(context).saveButtonLabel,
            onPressed: _save,
          ),
        ],
      ),
      body: CodeTheme(
        data: CodeThemeData(
          styles: _isDark ? atomOneDarkTheme : atomOneLightTheme,
        ),
        child: CodeField(
          controller: _controller,
          gutterStyle: const GutterStyle(
            showErrors: true,
            showFoldingHandles: false,
            showLineNumbers: true,
          ),
          expands: true,
          wrap: true,
        ),
      ),
    );
  }
}
