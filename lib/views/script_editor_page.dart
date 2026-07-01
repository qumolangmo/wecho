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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:highlight/languages/cpp.dart';
import '../l10n/app_localizations.dart';

class ScriptEditorPage extends StatefulWidget {
  final String initialCode;
  final Future<bool> Function(String code) onSave;
  final Stream<String>? compileErrorStream;

  const ScriptEditorPage({super.key, required this.initialCode, required this.onSave, this.compileErrorStream});

  @override
  State<ScriptEditorPage> createState() => _ScriptEditorPageState();
}

class _ScriptEditorPageState extends State<ScriptEditorPage> {
  late CodeController _controller;
  bool _isDark = true;
  StreamSubscription<String>? _errorSubscription;
  bool _waitingForCompile = false;

  @override
  void initState() {
    super.initState();

    _controller = CodeController(
      text: widget.initialCode,
      language: cpp,
    );

    _errorSubscription = widget.compileErrorStream?.listen((error) {
      if (!mounted) {
        return;
      }

      if (error.isNotEmpty) {
        _waitingForCompile = false;

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Compile Error'),
            content: SingleChildScrollView(
              child: Text(
                error,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
            ],
          ),
        );
      } else if (_waitingForCompile) {
        // compile success, close editor.
        _waitingForCompile = false;
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _waitingForCompile = true;

    final ok = await widget.onSave(_controller.text);

    if (!ok && mounted) {
      _waitingForCompile = false;

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Missing // @desc'),
          content: const Text(
            'Script must have a description on the first line:\n\n'
            'Example:\n'
            '// @desc: tremolo effect',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
          ],
        ),
      );
      return;
    }
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
