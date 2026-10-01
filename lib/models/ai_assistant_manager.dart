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

import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_config.dart';
import 'autoeq_index.dart';
import 'custom_ui_manager.dart';
import '../view_models/dsp_controller_view_model.dart';

/* Echo host protocol directive headers. Declared once and referenced by
 * the parser regexes, the feedback notes, the prompt and the trace logs.
 */
enum Directive {
  applyScript('[APPLY_SCRIPT]'),
  setEq('[SET_EQ]'),
  setParam('[SET_PARAM]'),
  set('[SET]'),
  listDevices('[LIST_DEVICES]'),
  useDevice('[USE_DEVICE]');

  final String header;
  const Directive(this.header);

  /* Regex-escaped header for embedding into patterns. */
  String get escaped => RegExp.escape(header);
}

/* The global AI assistant. It talks to any OpenAI-compatible chat
 * completions endpoint supplied by the user (no built-in model) and can
 * produce two kinds of artifacts the host knows how to apply:
 *   - DSP effect scripts (C, applied through DSPControllerViewModel.saveScript)
 *   - Custom UI scripts (Dart, applied through CustomUiManager.saveScriptSource)
 * The current DSP parameter snapshot is re-injected into every request, so
 * the model always reasons about the live configuration.
 */
class AiAssistantManager {
  static const String _kApiUrl = 'ai_api_url';
  static const String _kApiKey = 'ai_api_key';
  static const String _kModel = 'ai_model';

  static SharedPreferences? _prefs;
  static String _apiUrl = '';
  static String _apiKey = '';
  static String _model = '';

  /* Conversation history kept across page visits (user/assistant turns). */
  static final List<Map<String, String>> history = [];

  /* What the chat UI shows: user messages plus the pretty display version
   * of each reply (directive receipts, no host result messages). The model
   * context above stays separate.
   */
  static final List<Map<String, String>> displayHistory = [];
  static int _requestId = 0;

  /* True while an LLM request is in flight. Listened to directly by the
   * chat UI so a state change only rebuilds the loading indicator instead
   * of the whole panel.
   */
  static final ValueNotifier<bool> busy = ValueNotifier(false);

  /* Bumped when history is cleared so listening lists rebuild. */
  static final ValueNotifier<int> historyRevision = ValueNotifier(0);

  // must be called before runApp.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _apiUrl = _prefs?.getString(_kApiUrl) ?? '';
    _apiKey = _prefs?.getString(_kApiKey) ?? '';
    _model = _prefs?.getString(_kModel) ?? '';
  }

  static String get apiUrl => _apiUrl;
  static String get apiKey => _apiKey;
  static String get model => _model;
  static bool get isConfigured => _apiUrl.trim().isNotEmpty && _model.trim().isNotEmpty;

  static Future<void> setApiUrl(String v) async {
    _apiUrl = v;
    await _prefs?.setString(_kApiUrl, v);
  }

  static Future<void> setApiKey(String v) async {
    _apiKey = v;
    await _prefs?.setString(_kApiKey, v);
  }

  static Future<void> setModel(String v) async {
    _model = v;
    await _prefs?.setString(_kModel, v);
  }

  static void clearHistory() {
    history.clear();
    displayHistory.clear();
    historyRevision.value++;
  }

  /* Appends a host-side report (script apply results etc.) that only Echo
   * sees; the chat UI does not display it.
   */
  static void recordHostResult(String result) {
    history.add({'role': 'user', 'content': '[Echo host] $result'});
    if (history.length > 42) {
      history.removeRange(0, history.length - 42);
    }
  }

  /* Sends a user message with the live system prompt and returns the
   * assistant reply. Throws on network/HTTP/parse errors.
   */
  static Future<String> sendMessage(
      DSPControllerViewModel vm, String userMessage) async {
    final id = ++_requestId;
    history.add({'role': 'user', 'content': userMessage});
    displayHistory.add({'role': 'user', 'content': userMessage});
    busy.value = true;
    try {
      final raw = await _request(vm, id);
      /* A newer request may have been started meanwhile; drop stale replies. */
      if (id == _requestId) {
        final exec = await _executeDirectives(vm, raw);
        /* Keep the model's OWN directive lines in the history instead of
         * the rewritten receipts: the model started mirroring the receipt
         * style ("> param = value") and stopped emitting real directives.
         * The results come back as a separate host message. The UI list
         * gets the pretty display version without host messages.
         */
        history.add({'role': 'assistant', 'content': raw});
        if (exec.notes.isNotEmpty) {
          history.add({
            'role': 'user',
            'content': '[Echo host] Directive results:\n${exec.notes}',
          });
        }
        displayHistory.add({'role': 'assistant', 'content': exec.display});
        if (history.length > 42) {
          history.removeRange(0, history.length - 42);
        }
        if (displayHistory.length > 40) {
          displayHistory.removeRange(0, displayHistory.length - 40);
        }
        return exec.display;
      }
      return raw;
    } catch (_) {
      if (id == _requestId) {
        history.removeLast();
        displayHistory.removeLast();
      }
      rethrow;
    } finally {
      busy.value = false;
      streamingText.value = null;
    }
  }

  /* Directive protocol: the model can operate effects by emitting
   * [APPLY_SCRIPT] / [SET_EQ] / [SET] / [SET_PARAM] / [LIST_DEVICES] /
   * [USE_DEVICE] lines. The host executes them right after the reply
   * arrives. The UI shows each directive as a "> ..." receipt; the
   * conversation history keeps the model's original directive lines and
   * the results are returned separately as a host message, so the model
   * never learns to mirror receipts.
   */
  /* Directive lines may be indented, written as markdown list items, or
   * wrapped in bold markers, so the prefix tolerates all of them.
   */
  static const String _linePrefix = r'[ \t]*(?:[-*+][ \t]+|\*\*)?';
  static final RegExp _applyScriptDirective = RegExp(
      '^$_linePrefix${Directive.applyScript.escaped}[ \\t]*\\n(?=[ \\t]*```c)',
      multiLine: true);
  static final RegExp _setEqDirective = RegExp(
      '^$_linePrefix${Directive.setEq.escaped}[ \\t]*\$',
      multiLine: true);
  static final RegExp _fencedBlock =
      RegExp(r'```[a-zA-Z]*[ \t]*\n([\s\S]*?)```');
  static final RegExp _setDirective = RegExp(
      '^$_linePrefix${Directive.set.escaped}[ \\t]+(\\S+)[ \\t]+(.+?)\\s*\$',
      multiLine: true);
  /* The param name may contain spaces ("Vocal Tone"); the value is the
   * last token of the line.
   */
  static final RegExp _scriptParamDirective = RegExp(
      '^$_linePrefix${Directive.setParam.escaped}[ \\t]+(.+?)[ \\t]+(\\S+)\\s*\$',
      multiLine: true);
  static final RegExp _useDeviceDirective = RegExp(
      '^$_linePrefix${Directive.useDevice.escaped}[ \\t]+(.+?)\\s*\$',
      multiLine: true);
  static final RegExp _listDevicesDirective = RegExp(
      '^$_linePrefix${Directive.listDevices.escaped}[ \\t]+(.+?)\\s*\$',
      multiLine: true);
  static final RegExp _cBlock = RegExp(r'```c[ \t]*\n([\s\S]*?)```');

  /* Trace log of the whole LLM directive path; filter by "[Echo]". */
  static void _log(String message) {
    debugPrint('[Echo] $message');
  }

  /* Any directive-like token, used to report lines skipped as code blocks. */
  static final RegExp _directiveToken = RegExp(
      Directive.values.map((d) => d.escaped).join('|'));

  static String _describePending(ParamID id, dynamic value) =>
      '${id.name}=${value is List ? '${value.length} script params' : value}';

  /* Receipt-style fallback: the model sometimes echoes back the "> name =
   * value" receipts it has seen in the conversation instead of emitting a
   * real directive. When the name is a valid ParamID, execute it as [SET].
   */
  static final RegExp _receiptDirective = RegExp(
      '^$_linePrefix>[ \\t]*(\\S+)[ \\t]*=[ \\t]*(.+?)\\s*\$',
      multiLine: true);

  static bool _isValidParamName(String name) {
    try {
      ParamID.values.byName(name);
      return true;
    } catch (_) {
      return false;
    }
  }

  /* Receipt body without the "> " prefix, for the host results message. */
  static String _noteBody(String note) =>
      note.startsWith('> ') ? note.substring(2) : note;

  static Future<({String display, String notes})> _executeDirectives(
      DSPControllerViewModel vm, String content) async {
    var output = content;
    final notes = <String>[];
    _log('scan reply (${output.length} chars): '
        '${output.length > 200 ? '${output.substring(0, 200)}...' : output}');
    /* All param changes of one reply are collected here and pushed in a
     * single batch (updateAll with the initialize flag), because updateEffect
     * is not designed for rapid multi-parameter updates.
     */
    final pending = <ParamID, dynamic>{};
    /* [APPLY_SCRIPT] + the following ```c block (block is kept visible). */
    while (true) {
      final match = _applyScriptDirective.firstMatch(output);
      if (match == null) break;
      final block = _cBlock.firstMatch(output.substring(match.end));
      String note;
      if (block == null) {
        note = '> failed: missing ```c code block after ${Directive.applyScript.header}';
        _log('${Directive.applyScript.name}: $note');
      } else {
        final code = block.group(1)!.trim();
        try {
          final ok = await vm.saveScript(code);
          note = ok
              ? '> script applied and enabled by Echo'
              : '> failed: script missing @desc annotation';
        } catch (e) {
          note = '> failed: $e';
        }
        _log('${Directive.applyScript.name}: $note');
      }
      notes.add(_noteBody(note));
      output = output.replaceRange(match.start, match.end, note);
    }
    /* [SET_EQ] + the following fenced block (multi-line EQ config). */
    while (true) {
      final match = _setEqDirective.firstMatch(output);
      if (match == null) break;
      final block = _fencedBlock.firstMatch(output.substring(match.end));
      final note = block == null
          ? '> failed: missing fenced config block after ${Directive.setEq.header}'
          : _trySetEq(pending, block.group(1)!.trim());
      _log('${Directive.setEq.name}: $note');
      notes.add(_noteBody(note));
      output = output.replaceRange(match.start, match.end, note);
    }
    /* [SET] / [SET_PARAM] lines. Lines inside properly paired fenced code
     * blocks are examples, not directives, so they are skipped. A stray
     * unclosed fence must NOT swallow the directives after it.
     */
    final lines = output.split('\n');
    final skip = List<bool>.filled(lines.length, false);
    final marks = <int>[
      for (var i = 0; i < lines.length; i++)
        if (lines[i].trimLeft().startsWith('```')) i,
    ];
    if (marks.length.isOdd) marks.removeLast();
    for (var j = 0; j + 1 < marks.length; j += 2) {
      for (var k = marks[j] + 1; k < marks[j + 1]; k++) {
        skip[k] = true;
      }
    }
    for (var i = 0; i < lines.length; i++) {
      if (skip[i]) {
        /* Report directive-like lines swallowed by a code block: this is
         * how a valid [SET] can silently do nothing.
         */
        if (_directiveToken.hasMatch(lines[i])) {
          _log('SKIP line inside code block: ${lines[i].trim()}');
        }
        continue;
      }
      final setMatch = _setDirective.firstMatch(lines[i]);
      final scriptMatch = setMatch == null
          ? _scriptParamDirective.firstMatch(lines[i])
          : null;
      if (setMatch != null) {
        _log('directive: ${lines[i].trim()}');
        lines[i] =
            await _trySetParam(vm, pending, setMatch.group(1)!, setMatch.group(2)!);
        _log('result: ${lines[i]}');
        notes.add(_noteBody(lines[i]));
      } else if (scriptMatch != null) {
        _log('directive: ${lines[i].trim()}');
        lines[i] = await _trySetScriptParam(
            vm, pending, scriptMatch.group(1)!, scriptMatch.group(2)!);
        _log('result: ${lines[i]}');
        notes.add(_noteBody(lines[i]));
      } else {
        final listMatch = _listDevicesDirective.firstMatch(lines[i]);
        if (listMatch != null) {
          lines[i] = _listDevices(listMatch.group(1)!);
          _log('result: ${lines[i]}');
          notes.add(_noteBody(lines[i]));
        } else {
          final useMatch = _useDeviceDirective.firstMatch(lines[i]);
          if (useMatch != null) {
            lines[i] = await _useDevice(vm, pending, useMatch.group(1)!);
            _log('result: ${lines[i]}');
            notes.add(_noteBody(lines[i]));
          } else {
            /* Mirrored receipt line: "> someParam = value". */
            final receiptMatch = _receiptDirective.firstMatch(lines[i]);
            if (receiptMatch != null &&
                _isValidParamName(receiptMatch.group(1)!)) {
              _log('directive (mirrored receipt): ${lines[i].trim()}');
              lines[i] = await _trySetParam(
                  vm, pending, receiptMatch.group(1)!, receiptMatch.group(2)!);
              _log('result: ${lines[i]}');
              notes.add(_noteBody(lines[i]));
            }
          }
        }
      }
    }
    /* Push the changes: a single parameter takes the normal hot-update
     * path (no initialize flag); multiple parameters from one reply go
     * through the batch initialize push.
     */
    if (pending.length == 1) {
      final entry = pending.entries.first;
      _log('apply single: ${_describePending(entry.key, entry.value)} via update');
      await vm.update<dynamic>(entry.key, entry.value);
    } else if (pending.isNotEmpty) {
      _log('apply batch (${pending.length}): '
          '${pending.entries.map((e) => _describePending(e.key, e.value)).join(', ')} '
          'via updateAll');
      await vm.updateAll(pending);
    } else if (notes.isEmpty) {
      _log('no directive matched in this reply');
    }
    return (display: lines.join('\n'), notes: notes.join('\n'));
  }

  /* Apply a resolved script param change into the pending batch. */
  static String _applyScriptParam(Map<ParamID, dynamic> pending,
      List<ScriptParam> params, int index, String name, double value,
      String requested) {
    final p = params[index];
    /* The engine clamps by (min, max, step) on apply. */
    var v = value;
    if (v < p.min) v = p.min;
    if (v > p.max) v = p.max;
    final updated = List<ScriptParam>.of(params);
    updated[index] = ScriptParam(p.name, v, min: p.min, max: p.max, step: p.step);
    pending[ParamID.scriptEffectParams] = updated;
    return v != value
        ? '> script param ${p.name} = $v (clamped, requested $requested $value)'
        : '> script param ${p.name} = ${updated[index].value}';
  }

  /* PARAM(var, ..., "display") macros of the active script. */
  static final RegExp _paramMacro =
      RegExp(r'PARAM\s*\(\s*(\w+)\s*,[^)]*?"([^"]*)"\s*\)');

  /* Resolve a script param by display name (ScriptParam.name) or C
   * variable name from the PARAM macros. Returns (index, matchedName).
   */
  static (int, String)? _resolveScriptParam(
      List<ScriptParam> params, String code, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final m in _paramMacro.allMatches(code)) {
      if (m.group(1)!.toLowerCase() != q) continue;
      final display = m.group(2)!.isEmpty ? m.group(1)! : m.group(2)!;
      final index = params.indexWhere((p) => p.name == display);
      if (index >= 0) return (index, m.group(1)!);
    }
    return null;
  }

  /* "Display (var: x)" list for unknown-name error feedback. */
  static String _paramNameList(List<ScriptParam> params, String code) {
    final displayToVar = _paramDisplayToVar(code);
    return params.map((p) {
      final v = displayToVar[p.name];
      return (v == null || v == p.name) ? p.name : '${p.name} (var: $v)';
    }).join(', ');
  }

  /* Display name -> C variable name map of the active script. */
  static Map<String, String> _paramDisplayToVar(String code) {
    final map = <String, String>{};
    for (final m in _paramMacro.allMatches(code)) {
      map[m.group(2)!.isEmpty ? m.group(1)! : m.group(2)!] = m.group(1)!;
    }
    return map;
  }

  /* [SET_PARAM]: updates one PARAM of the active script effect by name.
   * Tolerates "name=value" and units in the value ("1.2dB"). Unknown-name
   * errors list the available PARAM names so the model can self-correct.
   * The change goes into the pending batch, so consecutive [SET_PARAM]
   * lines build on each other.
   */
  static Future<String> _trySetScriptParam(DSPControllerViewModel vm,
      Map<ParamID, dynamic> pending, String name, String raw) async {
    try {
      var target = name.trim();
      var valueText = _cleanValue(raw);
      if (target.contains('=')) {
        final parts = target.split('=');
        target = parts[0].trim();
        if (parts.length > 1 && parts[1].trim().isNotEmpty) {
          valueText = parts[1].trim();
        }
      }
      final params =
          pending[ParamID.scriptEffectParams] as List<ScriptParam>? ??
              vm.get<List<ScriptParam>>(ParamID.scriptEffectParams);
      if (params.isEmpty) return '> failed: no active script parameters';
      final value = _parseLooseDouble(valueText);
      if (value == null) {
        return '> failed: invalid value "$valueText" for $target';
      }
      final index = params
          .indexWhere((p) => p.name.toLowerCase() == target.toLowerCase());
      if (index < 0) {
        /* Fall back to the C variable name parsed from the PARAM macros. */
        final code = vm.get<String>(ParamID.scriptEffectCode);
        final resolved = _resolveScriptParam(params, code, target);
        if (resolved == null) {
          return '> failed: no param named "$target" (available: ${_paramNameList(params, code)})';
        }
        return _applyScriptParam(pending, params, resolved.$1, resolved.$2,
            value, target);
      }
      return _applyScriptParam(pending, params, index, params[index].name,
          value, target);
    } catch (e) {
      return '> failed: $e';
    }
  }

  /* First number in the text, tolerating trailing units like "dB". */
  static double? _parseLooseDouble(String text) {
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(text.trim());
    return match == null ? null : double.tryParse(match.group(0)!);
  }

  /* [LIST_DEVICES]: search the built-in AutoEq database by keyword. */
  static String _listDevices(String keyword) {
    final query = keyword.trim().toLowerCase();
    final names = <String>[];
    for (final e in kAutoEqIndex) {
      if (e.name.toLowerCase().contains(query)) names.add(e.name);
      if (names.length >= 20) break;
    }
    if (names.isEmpty) return '> no AutoEq device matching "$keyword"';
    return '> devices matching "$keyword": ${names.join(' | ')}';
  }

  /* [USE_DEVICE]: select a device from the AutoEq database by name (exact
   * match first, then prefix, then substring) and enable device simulation.
   */
  static Future<String> _useDevice(DSPControllerViewModel vm,
      Map<ParamID, dynamic> pending, String name) async {
    final query = name.trim().toLowerCase();
    AutoEqEntry? best;
    for (final e in kAutoEqIndex) {
      if (e.name.toLowerCase() == query) {
        best = e;
        break;
      }
    }
    if (best == null) {
      for (final e in kAutoEqIndex) {
        if (e.name.toLowerCase().startsWith(query)) {
          best = e;
          break;
        }
      }
    }
    if (best == null) {
      for (final e in kAutoEqIndex) {
        if (e.name.toLowerCase().contains(query)) {
          best = e;
          break;
        }
      }
    }
    if (best == null) return '> failed: device "$name" not in the AutoEq database';
    pending[ParamID.deviceSimulationEffectConfig] =
        'autoeq@${best.dataOffset}:${best.rowCount}';
    pending[ParamID.deviceSimulationEffectEnabled] = true;
    return '> device simulation enabled: ${best.name} '
        '(${kAutoEqTypes[best.typeId]}, rig ${kAutoEqRigs[best.rigId]})';
  }

  /* [SET_EQ]: stages a complete multi-line Equalizer APO config. */
  static String _trySetEq(Map<ParamID, dynamic> pending, String config) {
    pending[ParamID.iirEqualizerEffectConfig] = config;
    return '> iir equalizer config applied (${config.split('\n').length} lines)';
  }

  /* Strip markdown bold markers and a leading "=" separator from a
   * directive value ("= true", "true**", "2.5 dB" all become clean).
   */
  static String _cleanValue(String raw) {
    var text = raw.trim();
    if (text.startsWith('=')) text = text.substring(1).trim();
    while (text.endsWith('*')) {
      text = text.substring(0, text.length - 1).trim();
    }
    return text;
  }

  /* Loose boolean parse; null means the text is not a recognizable state. */
  static bool? _parseBool(String text) {
    final t = text.toLowerCase();
    if (t.contains('true') || t.contains('enable') || t == '1' || t == 'on') {
      return true;
    }
    if (t.contains('false') || t.contains('disable') || t == '0' || t == 'off') {
      return false;
    }
    return null;
  }

  static Future<String> _trySetParam(DSPControllerViewModel vm,
      Map<ParamID, dynamic> pending, String name, String raw) async {
    if (name == 'iirEqualizerEffectConfig') {
      /* Single-line [SET] can never carry the multi-line config. */
      return '> failed: set iirEqualizerEffectConfig via '
          '${Directive.setEq.header} with a fenced block';
    }
    try {
      final id = ParamID.values.byName(name);
      /* Later directives of the same reply must build on earlier ones. */
      final current =
          pending.containsKey(id) ? pending[id] : vm.get<dynamic>(id);
      /* Match the new value to the live parameter type. Booleans are set
       * to the exact requested state, never flipped.
       */
      final text = _cleanValue(raw);
      if (current is bool) {
        final value = _parseBool(text);
        if (value == null) return '> failed: invalid value "$text" for $name';
        pending[id] = value;
        return '> $name = $value';
      }
      if (current is int) {
        final value = _parseLooseDouble(text);
        if (value == null) return '> failed: invalid value "$text" for $name';
        pending[id] = value.round();
        return '> $name = ${value.round()}';
      }
      if (current is double) {
        final value = _parseLooseDouble(text);
        if (value == null) return '> failed: invalid value "$text" for $name';
        pending[id] = value;
        return '> $name = $value';
      }
      if (current is String) {
        pending[id] = text;
        return '> $name = $text';
      }
      return '> failed: unsupported type for $name';
    } on ArgumentError {
      return '> failed: unknown param $name';
    } catch (e) {
      return '> failed: $e';
    }
  }

  /* Live token stream for the in-flight request (null when idle). */
  static final ValueNotifier<String?> streamingText = ValueNotifier(null);

  static Future<String> _request(
      DSPControllerViewModel vm, int requestId) async {
    final uri = Uri.parse(_endpoint(_apiUrl));
    final headers = {
      'Content-Type': 'application/json',
      /* Some gateways only pass SSE through when explicitly asked. */
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
      if (_apiKey.trim().isNotEmpty) 'Authorization': 'Bearer ${_apiKey.trim()}',
    };
    final body = jsonEncode({
      'model': _model.trim(),
      'stream': true,
      'messages': _messages(vm),
    });

    final client = http.Client();
    try {
      final request = http.Request('POST', uri)
        ..headers.addAll(headers)
        ..body = body;
      final response =
          await client.send(request).timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        throw Exception('HTTP ${response.statusCode}: $errorBody');
      }

      final buffer = StringBuffer();
      var lastFlush = DateTime.fromMillisecondsSinceEpoch(0);
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        /* A newer request took over; stop emitting this stream. */
        if (requestId != _requestId) break;
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data.isEmpty) continue;
        if (data == '[DONE]') break;
        final chunk = jsonDecode(data);
        final choices = chunk['choices'];
        if (choices is! List || choices.isEmpty) continue;
        final delta = choices.first['delta'];
        final piece = delta is Map ? delta['content'] : null;
        if (piece is String && piece.isNotEmpty) {
          buffer.write(piece);
          /* Throttle UI updates to ~30fps. */
          final now = DateTime.now();
          if (now.difference(lastFlush).inMilliseconds >= 33 ||
              piece.contains('\n')) {
            lastFlush = now;
            streamingText.value = buffer.toString();
          }
        }
      }
      final content = buffer.toString();
      if (content.isEmpty) throw Exception('Empty response');
      return content;
    } finally {
      client.close();
    }
  }

  /* Accepts base urls like https://host, https://host/v1 or a full
   * chat/completions endpoint.
   */
  static String _endpoint(String baseUrl) {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url.endsWith('/chat/completions')
        ? url
        : '$url/chat/completions';
  }

  // -- system prompt ------------------------------------------------------------

  /* Message layout per request: static persona/script instructions first,
   * then the conversation history, then a FRESH config readout as the very
   * last message. Placing the readout at the end (not buried in the system
   * prompt) is what makes the model treat it as live data that overrides
   * any values mentioned earlier in the conversation.
   */
  static List<Map<String, String>> _messages(DSPControllerViewModel vm) {
    return [
      {'role': 'system', 'content': _staticSystemPrompt()},
      ...history,
      {
        'role': 'system',
        'content':
            '==== LIVE CONFIG READOUT (read from the engine RIGHT NOW, '
                'overrides any values mentioned earlier in this conversation) ====\n'
            '${_configSnapshot(vm)}',
      },
    ];
  }

  static String _staticSystemPrompt() {
    final buffer = StringBuffer();
    buffer.write(_kRoleSection);
    buffer.write(_kDspScriptSection);
    buffer.write(_kUiScriptSection);
    /* Expose the saved custom UI script so Echo can modify it across
     * sessions instead of writing from scratch every time.
     */
    final uiSource = CustomUiManager.scriptSource;
    if (uiSource.isNotEmpty) {
      buffer.write(
          '\n=== CURRENT CUSTOM UI SCRIPT (${CustomUiManager.scriptName}) ===\n');
      buffer.write(uiSource);
      buffer.write(
          '\nWhen the user asks to change the custom UI, EDIT this saved script and return the COMPLETE new version in one ```dart block - applying it replaces this file.\n');
    }
    final uiError = CustomUiManager.lastError;
    if (uiError != null) {
      buffer.write(
          '\n=== LAST CUSTOM UI SCRIPT ERROR ===\n$uiError\nThe currently saved custom UI script has this problem (compile or runtime). When the user asks anything about the UI, offer a fixed complete version in one ```dart block.\n');
    }
    return buffer.toString();
  }

  static String _configSnapshot(DSPControllerViewModel vm) {
    final specs = effectParamSpecs();
    final buffer = StringBuffer();
    for (final id in ParamID.values) {
      if (id == ParamID.scriptEffectParams) {
        /* Structured output: the model tunes script PARAMs by name via
         * [SET_PARAM], so it needs the live names, values and ranges.
         */
        try {
          final params = vm.get<List<ScriptParam>>(id);
          if (params.isEmpty) {
            buffer.writeln('scriptEffectParams: <no active script>');
          } else {
            final code = vm.get<String>(ParamID.scriptEffectCode);
            final descMatch = RegExp(r'@desc:\s*(.+)').firstMatch(code);
            final desc = descMatch?.group(1)?.trim() ?? 'unknown';
            buffer.writeln('scriptEffectParams: script "$desc"');
            final displayToVar = _paramDisplayToVar(code);
            for (final p in params) {
              final v = displayToVar[p.name];
              final tag = (v == null || v == p.name) ? '' : ' (var: $v)';
              buffer.writeln(
                  '  ${p.name}$tag: ${p.value} (min ${p.min}, max ${p.max}, step ${p.step})');
            }
          }
        } catch (_) {
          buffer.writeln('scriptEffectParams: <unavailable>');
        }
        continue;
      }
      try {
        final raw = vm.get<dynamic>(id);
        final text = '$raw';
        /* Multi-line values are shown escaped so the model can see where
         * one field ends and the next begins.
         */
        final escaped =
            text.contains('\n') ? text.replaceAll('\n', r'\n') : text;
        /* Slider clamp range from the effect-card table. */
        final spec = specs[id];
        final range = spec == null
            ? ''
            : ' (min ${spec.$1}, max ${spec.$2}${spec.$3.isEmpty ? '' : ', unit ${spec.$3}'})';
        buffer.writeln('${id.name}: $escaped$range');
      } catch (_) {
        buffer.writeln('${id.name}: <unavailable>');
      }
    }
    return buffer.toString();
  }

  /* Not const: the protocol headers are interpolated from the enum. */
  static final String _kRoleSection = '''
You are Echo, the built-in agent of WEcho, a system-wide audio processing app (Android + Windows) with a real-time DSP engine. When asked who you are, introduce yourself as: "I am Echo, WEcho's agent." You help the user with three things:
1. Tuning: a LIVE CONFIG READOUT is appended after the conversation history with EVERY request. It is freshly read from the engine at that moment, so those values always reflect the current state and override any values mentioned in earlier turns. Trust the readout, never stale values from your own earlier replies.
2. Writing DSP effect scripts in C (the user applies them with one tap).
3. Writing custom UI scripts in Dart that fully replace the app interface (the user applies them with one tap).
Reply in the user's language. Be concise. When you produce code, output it in a fenced code block: use ```c for DSP effect scripts and ```dart for custom UI scripts. Only output code the user asked for, and keep the rest of the answer short.

You can also operate the DSP engine directly. When the user asks you to actually apply or change something, emit directive lines (each on its own line, exactly). NEVER wrap directive lines in code blocks and NEVER put them in prose - the host only executes bare directive lines:
The engine ONLY reacts to directive lines. A text-only answer like "OK, it is now off" changes NOTHING. Whenever the user asks for a state change, you MUST emit the directive line in that same reply - do not assume the change is already in effect, do not rely on your earlier directives, and never just describe what you would set. Check the LIVE readout for the current state and emit the directive with the exact target value.
- ${Directive.applyScript.header} on the line immediately before a ```c code block: the host saves that script as the active script effect and enables it automatically. To change script parameters afterwards, emit ${Directive.setParam.header} lines AFTER the block.
- ${Directive.set.header} <param_name> <value>: sets a live DSP parameter to the exact requested value, e.g. ${Directive.set.header} gainEffectGain 2.5. For boolean parameters (the "...Enabled" switches) always set the exact target state with true/false, e.g. ${Directive.set.header} convolveEnabled true. NEVER flip a switch based on a value you read earlier - the user may have changed it meanwhile.
- ${Directive.setParam.header} <param_name> <value>: sets ONE PARAM of the active script effect per line. Use the display name OR the C variable name, both as listed under scriptEffectParams ("Display (var: x)"). When the display name contains spaces, keep the spaces and put the value as the last word. One parameter per line, e.g.:
${Directive.setParam.header} Vocal Tone 0.5
${Directive.setParam.header} gain 1.2
- ${Directive.setEq.header} on its own line, followed by a fenced block containing the complete Equalizer APO config (the Preamp line AND every Filter line). This is the ONLY way to change iirEqualizerEffectConfig, e.g.:
${Directive.setEq.header}
```apo
Preamp: -2.0 dB
Filter 1: ON PK Fc 31 Hz Gain 0.0 dB Q 1.00
```
- ${Directive.listDevices.header} <keyword>: searches the built-in AutoEq headphone database and returns up to 20 device names, e.g. ${Directive.listDevices.header} sony
- ${Directive.useDevice.header} <device_name>: enables Device Simulation with that device's AutoEq correction curve. Use ${Directive.listDevices.header} first when unsure of the exact name, e.g. ${Directive.useDevice.header} Sony WF-1000XM4
Multi-line values in the snapshot are shown with \\n escapes; expand them back to real lines inside the fenced block.
Numeric parameters carry their clamp range as "(min X, max Y, unit Z)" in the snapshot; always keep ${Directive.set.header} values within that range and mind the unit.
Use ParamID names exactly as they appear in the configuration snapshot. Your directive lines are kept verbatim in this conversation, and the host reports their results as separate messages starting with "[Echo host]" - those are host-injected reports, not user speech. NEVER output receipt-style lines ("> param = value") yourself; receipts are host-generated. If you want to change something, always emit a real directive.

''';

  static const String _kDspScriptSection = '''
==== DSP EFFECT SCRIPT FORMAT (C) ====
A script is a C translation unit compiled with TCC at runtime. Rules:
- First line must be a comment naming the script: // @desc: My Effect
- Adjustable parameters are declared with the PARAM macro (max 16):
  PARAM(variable_name, min_value, max_value, step, default_value, "display name of UI");
- SAMPLE_RATE and SAMPLES_PER_CHANNEL are predefined macros; store them into globals if needed.
- void setParams(ScriptParams* params) is called once: read param values (params[i].value in PARAM declaration order) and initialize ALL filter state here. new_* may only be called here (calling it in run leaks memory). Allocated objects are garbage collected, never free manually.
- void run(float* in_l, float* in_r, float* out_l, float* out_r) processes one block of samples in a for loop over samples_per_channel.
- Filter/objects are mono: create one per channel for stereo (except convolver which is stereo).
- memcpy and memset are available. Standard math names (sin, exp, pow, sqrt, fabs, fmin...) are redirected to the built-ins below.
- Do not implement a soft limiter (the engine already limits).
Entry-point example:

// @desc: wecho dsp template code (don't override this code)
float ll = 0, rr = 0;
#ifndef PARAM
#define PARAM(var, min, max, step, default_value, "display_name") float var = default_value;
#endif

PARAM(gain, 0, 1.8, 0.1, 1.0, "Gain");

Biquad_ hp_l, hp_r;
const int sample_rate = SAMPLE_RATE;
const int samples_per_channel = SAMPLES_PER_CHANNEL;

void setParams(ScriptParams* params) {
    gain = params[0].value;
    hp_l = new_biquad();
    hp_r = new_biquad();
    biquad_reset(hp_l);
    biquad_reset(hp_r);
    biquad_set_lp(hp_l, 10000.0, 0.7071);
    biquad_set_lp(hp_r, 10000.0, 0.7071);
}

void run(float* in_l, float* in_r, float* out_l, float* out_r) {
    for (int i = 0; i < samples_per_channel; i++) {
        float l = in_l[i];
        float r = in_r[i];
        float l_hp = biquad_process(hp_l, l);
        float r_hp = biquad_process(hp_r, r);
        float dl = l_hp - ll;
        float dr = r_hp - rr;
        ll = l_hp;
        rr = r_hp;
        out_l[i] = dl * gain + l;
        out_r[i] = dr * gain + r;
    }
}

Valid API functions:
float _math_sin(float x); _math_sinh; _math_cos; _math_cosh; _math_tan; _math_tanh; _math_atan; _math_atanh; _math_exp; _math_log; _math_log2; _math_log10; float _math_pow(float x, float y); _math_sqrt; _math_fabs; float _math_fmod(float x, float y); _math_floor; _math_ceil; float _math_fmin(float x, float y); float _math_fmax(float x, float y);
Biquad_ new_biquad(); void biquad_reset(Biquad_ ctx); void biquad_set_hp(Biquad_ ctx, float cutoff, float q); void biquad_set_lp(Biquad_ ctx, float cutoff, float q); void biquad_set_peak(Biquad_ ctx, float cutoff, float q, float gain); void biquad_set_ls(Biquad_ ctx, float cutoff, float q, float gain); void biquad_set_hs(Biquad_ ctx, float cutoff, float q, float gain); void biquad_set_coeffs(Biquad_ ctx, double a0, double a1, double a2, double b0, double b1, double b2); float biquad_process(Biquad_ ctx, float input); void biquad_process_block(Biquad_ ctx, float* input, float* output);
DelayLine_ new_delay_line(); void delay_line_reset(DelayLine_ ctx); void delay_line_set_delay(DelayLine_ ctx, int samples); /* max 8192 */ float delay_line_process(DelayLine_ ctx, float input); void delay_line_process_block(DelayLine_ ctx, float* input, float* output); float delay_line_read(DelayLine_ ctx); void delay_line_read_block(DelayLine_ ctx, float* output); void delay_line_write(DelayLine_ ctx, float input); void delay_line_write_block(DelayLine_ ctx, float* input);
Convolver_ new_convolver(); void convolver_reset(Convolver_ ctx); void convolver_set_ir(Convolver_ ctx, float* ir_l, float* ir_r, int samples); void convolver_set_ir_path(Convolver_ ctx, const char* path); void convolver_process_block(Convolver_ ctx, float* input_l, float* input_r, float* output_l, float* output_r);
Harmonic_ new_harmonic(); void harmonic_reset(Harmonic_ ctx); void harmonic_set_coeffs(Harmonic_ ctx, float base, float order2, float order3, float order4, float order5, float order6, float order7, float order8); float harmonic_process(Harmonic_ ctx, float input); void harmonic_process_block(Harmonic_ ctx, float* input, float* output);

''';

  static final String _kUiScriptSection = '''
==== CUSTOM UI SCRIPT FORMAT (Dart) ====
A UI script is interpreted by D4rt and can fully replace the app interface. Contract:
- The script must import exactly: import 'package:wecho/custom_ui_api.dart';
- It must define a top-level function: Widget build(ctx)  (ctx is UIScriptContext)
- The script is stateless; all state comes from ctx. Any error falls back to the native UI.
- NEVER call ctx.update() or ctx.toggleCapture() inside build() - build must only READ state. Writing state in build freezes the app in an endless rebuild loop.
- NEVER declare build() as async (Widget build(ctx) must return a widget synchronously; an async build is rejected).
- NEVER run endless loops that write state (e.g. a while(true) poller calling ctx.update). If you want live-updating values, provide a refresh button instead - the host throttles runaway rebuilds and the UI will stop updating.

UIScriptContext members:
- dynamic get(ParamID id)  reads a live parameter value, e.g. ctx.get(ParamID.gainEffectGain)
- Future<void> update(ParamID id, dynamic value)  writes a parameter
- bool isExpanded(String key) / void toggleExpanded(String key)  card expansion state
- bool isCapturing  live capture state (read-only; you may display it)
- void toggleCapture() / void startCaptureWorkflow()  reserved - do NOT call them and do NOT expose any capture start control (see CAPTURE RULE)
- bool masterEnabled  master DSP on/off (the power switch)
- void updateMasterEnabled(bool enabled)  sets the master DSP switch
- double latencyMs  last polled processing latency in milliseconds
- String currentAudioOutput  current audio output device id
- String activeScriptDesc  name of the active script effect ('' when none)
- Future<bool> saveScript(String code)  compiles and pushes a DSP C script to the engine; returns false on compile error
- Future<List<double>?> getDeviceSimulationFreqResponse()  256-point dB response curve (20 Hz - 20 kHz) of device simulation, for custom plots
- void openSettings()  pushes the native settings page
- ColorScheme colorScheme (primary, onPrimary, secondary, onSecondary, surface, onSurface, onSurfaceVariant, surfaceContainerHighest, error, onError, outline)
- bool isDark

CAPTURE RULE: audio capture is started silently by the host when the custom UI mounts (page init) - the user never sees a consent flow or start button from the script. You must NOT call ctx.startCaptureWorkflow() or ctx.toggleCapture(), must NOT place any start/stop capture button or engine-start guard flag in the UI, and must NOT run the engine startup yourself. ctx.isCapturing is read-only state you may display. If you use AppHeader, always pass showCaptureButton: false.

Available ParamID enum values: ${ParamID.values.map((e) => e.name).join(', ')}.

Widgets and helpers (Flutter-like, bridged subset):
- Text(String data, {TextStyle? style, TextAlign? textAlign, TextOverflow? overflow})
- Icon(IconData icon, {double? size, Color? color})
- SizedBox({double? width, double? height, Widget? child})
- Padding({EdgeInsetsGeometry padding, Widget? child})
- Expanded({int flex, Widget? child}) / Flexible / Spacer({int? flex})
- Column({List<Widget> children, MainAxisAlignment mainAxisAlignment, CrossAxisAlignment crossAxisAlignment, MainAxisSize mainAxisSize})
- Row({List<Widget> children, MainAxisAlignment mainAxisAlignment, CrossAxisAlignment crossAxisAlignment, MainAxisSize mainAxisSize})
- Stack({List<Widget> children}) / Positioned({double? left, double? top, double? right, double? bottom, Widget? child})
- Center({Widget? child, double? widthFactor, double? heightFactor})
- Align({AlignmentGeometry alignment, Widget? child})
- Container({Widget? child, EdgeInsetsGeometry? padding, Color? color, double? width, double? height, AlignmentGeometry? alignment, BoxDecoration? decoration})
- GestureDetector({VoidCallback? onTap, Widget? child})
- Opacity({double opacity, Widget? child})
- SingleChildScrollView({Widget? child})
- Divider({double? height, double? thickness, Color? color, double? indent, double? endIndent})
- BoxDecoration({Color? color, BorderRadius? borderRadius})
- TextStyle({double? fontSize, FontWeight? fontWeight, Color? color, double? height})
- EdgeInsets.all(double), EdgeInsets.symmetric({double horizontal, double vertical}), EdgeInsets.only({double left, double top, double right, double bottom})
- BorderRadius.circular(double radius)
- Alignment.center, topLeft, topRight, bottomLeft, bottomRight, centerLeft, centerRight
- Color(int 0xAARRGGBB), Color.fromARGB(int a, int r, int g, int b), Color.fromRGBO(int r, int g, int b, double opacity), .withValues(alpha: double)
- Colors.white/black/transparent/red/green/blue/grey/amber/orange
- FontWeight.w100..w900, bold, normal
- Enums: MainAxisAlignment.start/center/end/spaceBetween/spaceAround/spaceEvenly, CrossAxisAlignment.start/center/end/stretch, MainAxisSize.min/max, TextAlign.left/center/right, TextOverflow.ellipsis/clip/fade/visible
- Icons constants: settings, close, add, remove, check, chevronRight, chevronLeft, arrowBack, arrowForward, playArrow, pause, stop, skipNext, skipPrevious, volumeUp, volumeOff, headphones, equalizer, graphicEq, musicNote, home, refresh, download, upload, delete, edit, search, moreVert, darkMode, lightMode, power, star, favorite, info, warning, tune, palette, powerSettingsNew, lock, lockOpen, densitySmall

App-styled components:
- NeumorphicButton({List<Widget> children, VoidCallback? onTap, bool enabled, EdgeInsets padding, double borderRadius})
- NeumorphicSlider({String label, double value, double min, double max, String unit, int? divisions, void Function(double)? onChanged, bool enabled, bool showDivider})
- NeumorphicToggle({String label, bool value, void Function(bool)? onChanged, bool enabled})
- NeumorphicSelector({List<SelectorItem> items, dynamic selectedValue, void Function(dynamic)? onSelect, void Function(dynamic)? onDelete, bool enabled, String hint})
- SelectorItem({dynamic value, String label, bool deletable})
- ControlCard({IconData icon, String title, String description, double value, double min, double max, String unit, bool expanded, VoidCallback onToggleExpand, void Function(double) onChanged})  all arguments required
- GenericControlCard({IconData icon, String title, String subtitle, String description, bool enabled, bool? expanded, VoidCallback? onToggleExpand, void Function(bool) onToggle, List<Widget> children})

Full host panels (drop-in, fully interactive):
- AppHeader({VoidCallback? onSettingsPressed, VoidCallback? onCapturePressed, bool isCapturing, bool showCaptureButton, double processingLatencyMs})  native title bar with WEcho title, capture/latency readouts
- GraphicEqPanel({String config, void Function(String) onConfigChanged, bool enabled})  the FULL IIR equalizer: drag-to-fit response plot, presets, band count, preamp, per-band editor. Bind config to ctx.get(ParamID.iirEqualizerEffectConfig) and push onConfigChanged back with ctx.update(ParamID.iirEqualizerEffectConfig, newConfig)
- DeviceSimulationCard({required viewModel})  the FULL device-simulation card (device search, pickers, response plot, apply). Always pass viewModel: ctx.viewModel

Example:

import 'package:wecho/custom_ui_api.dart';

Widget build(ctx) {
  final cs = ctx.colorScheme;
  final gain = ctx.get(ParamID.gainEffectGain) as num;
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Global Gain', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface)),
        Text('\${gain.toStringAsFixed(1)} dB', style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
        NeumorphicSlider(
          label: 'Gain',
          value: gain.toDouble(),
          min: -12,
          max: 12,
          unit: ' dB',
          onChanged: (v) => ctx.update(ParamID.gainEffectGain, v.round()),
        ),
      ],
    ),
  );
}
''';
}
