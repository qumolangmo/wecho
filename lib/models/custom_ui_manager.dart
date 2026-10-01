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

import 'dart:io';

import 'package:d4rt/d4rt.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../components/settings_page.dart';
import '../view_models/dsp_controller_view_model.dart';
import 'ui_script_bridges.dart';

/* Owns the custom UI feature state: the enable flag (shared with the Android
 * quick settings tile through SharedPreferences), the imported script slots
 * and the D4rt interpreter that renders the selected one.
 */
class CustomUiManager {
  static const String _kEnabledKey = 'custom_ui_enabled';
  static const String _kScriptKey = 'custom_ui_script';
  static const String _defaultScriptName = 'main.dart';

  static SharedPreferences? _prefs;
  static D4rt? _interpreter;
  static PrecompiledScript? _script;
  static String _scriptName = _defaultScriptName;
  static String _scriptSource = '';

  /* Whether the imported script currently replaces the native UI. The
   * settings switch and the quick settings tile both write this flag.
   */
  static final ValueNotifier<bool> enabled = ValueNotifier(false);

  /* Bumped whenever the active script must be re-built (import while on). */
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static bool get hasScript => _script != null;

  /* Source text of the selected script, kept for the AI assistant prompt. */
  static String get scriptSource => _scriptSource;

  static String get scriptName => _scriptName;

  /* Last D4rt compile/build error of the selected script, or null. Kept so
   * the AI assistant can see and fix broken scripts.
   */
  static String? lastError;

  /* Rebuild-storm guard: a script must be stateless and never write state
   * inside build(). If it does, the state change would trigger a rebuild,
   * which runs build() again, which writes again - an endless per-frame
   * loop that freezes the UI. While a script build is running, state-change
   * notifications are suppressed (and logged), breaking the cycle; the next
   * real user interaction refreshes the UI.
   */
  static bool _building = false;
  static int _suppressedWarnings = 0;

  /* Measured cost of the last script build in ms. The root uses it as the
   * rebuild throttle gap, so a slow script can never occupy more than about
   * half of the main thread no matter how fast state changes arrive.
   */
  static int lastBuildMs = 0;

  static bool get isBuilding => _building;

  /* Script session generation. Bumped whenever the loaded script changes
   * or the custom UI turns off. UIScriptContext instances record the
   * generation they were created in; write calls from stale generations
   * become no-ops, so async closures of an unloaded script (ghost loops)
   * cannot keep driving the view model after a UI switch.
   */
  static int _generation = 0;
  static int get currentGeneration => _generation;
  static void _endScriptSession() => _generation++;

  // must be called before runApp.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _scriptName = _prefs?.getString(_kScriptKey) ?? _defaultScriptName;
    if (_prefs?.getBool(_kEnabledKey) ?? false) {
      /* Only raise the flag when the script actually loaded; a broken
       * script keeps the app on the native home.
       */
      await _loadScript();
      if (_script != null) {
        enabled.value = true;
      }
    }
  }

  /* Re-reads the persisted flag. The Android quick settings tile can flip it
   * while the app is backgrounded, so the host re-checks on app resume.
   */
  static Future<void> refreshEnabled() async {
    final value = _prefs?.getBool(_kEnabledKey) ?? false;
    if (value == enabled.value) return;
    if (!value) {
      _endScriptSession();
    }
    if (value && _script == null) {
      await _loadScript();
    }
    enabled.value = value;
  }

  static Future<void> setEnabled(bool value) async {
    if (!value) {
      /* The script tree goes away: kill its async write channel. */
      _endScriptSession();
    }
    if (value && _script == null) {
      await _loadScript();
    }
    enabled.value = value;
    await _prefs?.setBool(_kEnabledKey, value);
  }

  /* Copies the picked .dart file into the scripts directory under its own
   * name and selects it. Importing does not enable the custom UI by itself.
   * Returns null when the user cancelled the picker, true on success, false
   * on failure.
   */
  static Future<bool?> importScript() async {
    try {
      final result = await FilePicker.pickFiles(
          type: FileType.custom, allowedExtensions: ['dart'], withData: true);
      final picked = result?.files.single;
      final bytes = picked?.bytes;
      if (bytes == null) return null;
      final name = picked!.name.isNotEmpty ? picked.name : _defaultScriptName;
      final dir = await _scriptsDir();
      await dir.create(recursive: true);
      await File('${dir.path}${Platform.pathSeparator}$name')
          .writeAsBytes(bytes, flush: true);
      await _select(name);
      if (enabled.value) {
        revision.value++;
      }
      return true;
    } catch (e) {
      debugPrint('CustomUi: import failed: $e');
      return false;
    }
  }

  /* Exports a script file to a user-chosen location. Returns null when the
   * user cancelled the picker, true on success, false on failure.
   */
  static Future<bool?> exportScript(String name) async {
    try {
      final file = File(
          '${(await _scriptsDir()).path}${Platform.pathSeparator}$name');
      if (!await file.exists()) return false;
      final bytes = await file.readAsBytes();
      final result = await FilePicker.saveFile(fileName: name, bytes: bytes);
      return result != null;
    } catch (e) {
      debugPrint('CustomUi: export failed: $e');
      return false;
    }
  }

  /* Saves script source text into the selected slot (AI assistant path).
   * Reloads and bumps revision when the custom UI is active.
   */
  static Future<void> saveScriptSource(String source) async {
    final file = await _scriptFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(source, flush: true);
    await _loadScript();
    if (enabled.value) {
      revision.value++;
    }
  }

  /* Lists the imported script file names. */
  static Future<List<String>> listScripts() async {
    final dir = await _scriptsDir();
    if (!await dir.exists()) return const [];
    final names = <String>[];
    await for (final entry in dir.list()) {
      if (entry is File && entry.path.endsWith('.dart')) {
        final segments = entry.uri.pathSegments;
        names.add(segments.last);
      }
    }
    names.sort();
    return names;
  }

  /* Selects which script the engine uses (and the AI assistant edits). */
  static Future<void> selectScript(String name) async {
    if (name == _scriptName && _script != null) return;
    await _select(name);
    if (enabled.value) {
      revision.value++;
    }
  }

  /* Deletes an imported script. Deleting the selected one falls back to the
   * default name and turns the custom UI off, so the engine never points at
   * a missing file.
   */
  static Future<void> deleteScript(String name) async {
    final file = File(
        '${(await _scriptsDir()).path}${Platform.pathSeparator}$name');
    if (await file.exists()) {
      await file.delete();
    }
    if (name == _scriptName) {
      _script = null;
      _interpreter = null;
      _scriptSource = '';
      await _select(_defaultScriptName);
      await setEnabled(false);
      revision.value++;
    }
  }

  static Future<void> _select(String name) async {
    _scriptName = name;
    await _prefs?.setString(_kScriptKey, name);
    await _loadScript();
  }

  /* Runs the script's `Widget build(ctx)` entry point. Returns null when no
   * script is loaded or the script failed, letting the host fall back to the
   * native UI.
   */
  static Widget? buildUi(UIScriptContext ctx) {
    final interpreter = _interpreter;
    final script = _script;
    if (interpreter == null || script == null) return null;
    _building = true;
    try {
      final sw = Stopwatch()..start();
      final result = interpreter.executeCompiled(script,
          name: 'build', positionalArgs: [ctx]);
      lastBuildMs = sw.elapsedMilliseconds;
      if (lastBuildMs > 50) {
        debugPrint('CustomUi: script build took ${lastBuildMs}ms');
      }
      /* An async build() returns a Future instead of a widget: the tree
       * would fall back to native while the async continuation keeps
       * running (and writing state) forever. Report it as a script error so
       * the AI assistant can fix the script.
       */
      if (result is Future) {
        lastError =
            'build() must not be async - declare it as Widget build(ctx) and return the widget synchronously';
        debugPrint('CustomUi: script build returned a Future (async build?)');
        return null;
      }
      if (result is Widget) {
        lastError = null;
        return result;
      }
      return null;
    } catch (e) {
      debugPrint('CustomUi: script build failed: $e');
      lastError = e.toString();
      return null;
    } finally {
      _building = false;
    }
  }

  static Future<void> _loadScript() async {
    /* A (re)load starts a new script session: every async closure of the
     * previously loaded script becomes stale and its writes no-op.
     */
    _endScriptSession();
    try {
      final file = await _scriptFile();
      if (!await file.exists()) {
        _interpreter = null;
        _script = null;
        _scriptSource = '';
        lastError = null;
        return;
      }
      final source = await file.readAsString();
      _scriptSource = source;
      final interpreter = D4rt();
      registerUiScriptBridges(interpreter);
      final sw = Stopwatch()..start();
      _script = interpreter.compile(source: source);
      debugPrint('CustomUi: compiled $_scriptName in ${sw.elapsedMilliseconds}ms');
      _interpreter = interpreter;
      lastError = null;
    } catch (e) {
      debugPrint('CustomUi: failed to load UI script: $e');
      _interpreter = null;
      _script = null;
      lastError = e.toString();
    }
  }

  static Future<Directory> _scriptsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return Directory(
        '${dir.path}${Platform.pathSeparator}wecho_ui');
  }

  static Future<File> _scriptFile() async {
    return File(
        '${(await _scriptsDir()).path}${Platform.pathSeparator}$_scriptName');
  }
}

/* Slots between the app shell and the native home widget. When the custom UI
 * flag is on, the imported script's build() replaces the whole native
 * subtree; any script error falls back to [native].
 */
class CustomUiRoot extends StatefulWidget {
  final Widget native;
  final DSPControllerViewModel viewModel;

  const CustomUiRoot(
      {super.key, required this.native, required this.viewModel});

  @override
  State<CustomUiRoot> createState() => _CustomUiRootState();
}

class _CustomUiRootState extends State<CustomUiRoot>
    with WidgetsBindingObserver {
  /* Throttle state for rebuilds. Leading edge rebuilds immediately, then
   * merges everything arriving during the next gap; the gap adapts to the
   * measured script build cost, so even a script looping async state writes
   * cannot saturate the main thread with full D4rt builds.
   */
  bool _throttling = false;
  bool _pending = false;
  Timer? _throttleTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    /* Listen through the multi-cast API: the legacy onStateChanged field is
     * overwritten by native pages on mount/dispose, so wrapping it here made
     * the script's notification channel die after any UI switch. Registered
     * listeners survive those switches.
     */
    widget.viewModel.addStateListener(_onVmStateChanged);
    CustomUiManager.revision.addListener(_onRevisionChanged);
    /* When the script replaces the native home on a cold start, the native
     * home never mounts and its capture workflow never runs (MediaProjection
     * consent, foreground service). startCaptureWorkflow re-syncs the status
     * first, so calling it here is safe even when capture is already up.
     */
    if (CustomUiManager.enabled.value) {
      widget.viewModel.initialized.then((_) {
        if (mounted) widget.viewModel.startCaptureWorkflow();
      });
    }
  }

  /* Receives every native state change. In-build changes are suppressed
   * (the signature of a script writing state in build()); the rest are
   * merged into a throttled rebuild.
   */
  void _onVmStateChanged() {
    if (CustomUiManager.isBuilding) {
      if (CustomUiManager._suppressedWarnings < 3) {
        CustomUiManager._suppressedWarnings++;
        debugPrint('CustomUi: state change during script build suppressed '
            '(the script must not update state in build())');
      }
      return;
    }
    _scheduleRebuild();
  }

  void _onRevisionChanged() {
    _scheduleRebuild();
  }

  void _scheduleRebuild() {
    if (!mounted) return;
    if (_throttling) {
      _pending = true;
      return;
    }
    _throttling = true;
    setState(() {});
    final gapMs =
        CustomUiManager.lastBuildMs < 50 ? 50 : CustomUiManager.lastBuildMs;
    _throttleTimer = Timer(Duration(milliseconds: gapMs), () {
      _throttling = false;
      if (_pending) {
        _pending = false;
        _scheduleRebuild();
      }
    });
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    widget.viewModel.removeStateListener(_onVmStateChanged);
    CustomUiManager.revision.removeListener(_onRevisionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    /* The quick settings tile flips the flag while the app is backgrounded. */
    if (state == AppLifecycleState.resumed) {
      CustomUiManager.refreshEnabled();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: CustomUiManager.enabled,
      builder: (context, isCustomOn, _) {
        if (!isCustomOn) return widget.native;
        return _buildScriptTree(context);
      },
    );
  }

  Widget _buildScriptTree(BuildContext context) {
    final theme = Theme.of(context);
    final ui = CustomUiManager.buildUi(UIScriptContext(
        widget.viewModel,
        theme.colorScheme,
        theme.brightness == Brightness.dark,
        onOpenSettings: () {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SettingsPage(viewModel: widget.viewModel)));
        }));
    if (ui == null) return widget.native;
    /* The script tree renders outside any Scaffold: provide the
     * Material ancestor required by Material widgets inside the
     * bridges (the Switch in NeumorphicToggle etc.).
     */
    return Material(type: MaterialType.transparency, child: ui);
  }
}
