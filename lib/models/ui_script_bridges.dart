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

import 'package:d4rt/d4rt.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'audio_config.dart';
import 'custom_ui_manager.dart';
import '../components/components.dart';
import '../view_models/dsp_controller_view_model.dart';

/* The single import URI exposed to UI scripts. Every bridged type below is
 * registered under this namespace, so a script only ever needs:
 *   import 'package:wecho/custom_ui_api.dart';
 */
const String uiScriptLibraryUri = 'package:wecho/custom_ui_api.dart';

/* The only channel between a UI script and the host app. Scripts read state
 * through [get] / [isExpanded], write through [update] / [toggleExpanded],
 * drive every host capability that reaches the Kotlin DSP layer, and
 * receive a read-only snapshot of the active theme.
 */
class UIScriptContext {
  final DSPControllerViewModel viewModel;
  final ColorScheme colorScheme;
  final bool isDark;

  /* Injected by the host (CustomUiRoot): pushes the native settings page.
   * Scripts get full navigation without touching the navigator themselves.
   */
  final void Function()? onOpenSettings;

  UIScriptContext(this.viewModel, this.colorScheme, this.isDark,
      {this.onOpenSettings});

  /* Lifetime marker. CustomUiManager bumps its generation whenever the
   * loaded script changes or the custom UI is disabled. A script may
   * outlive its own tree (async closures keep running after unmount), so
   * every write/action call from a stale generation is a no-op - a ghost
   * loop of an unloaded script cannot keep driving the view model.
   */
  final int _generation = CustomUiManager.currentGeneration;

  bool get _alive => _generation == CustomUiManager.currentGeneration;

  dynamic get(ParamID id) => viewModel.get<dynamic>(id);

  void update(ParamID id, dynamic value) {
    if (!_alive) return;
    viewModel.update(id, value);
  }

  bool isExpanded(String key) => viewModel.isExpanded(key);

  void toggleExpanded(String key) {
    if (!_alive) return;
    viewModel.toggleExpanded(key);
  }

  /* Capture control: capture is started silently by the host when the
   * custom UI mounts (CustomUiRoot.initState). Scripts must not expose a
   * start-capture entry; toggleCapture stays available for compatibility.
   */
  bool get isCapturing => viewModel.isCapturing;

  Future<void> toggleCapture() async {
    if (!_alive) return;
    await viewModel.toggleCapture();
  }

  /* ---- host capabilities that reach the Kotlin DSP layer ---- */

  /* Idempotent engine startup. The host calls this once when the custom
   * UI mounts; scripts must not call it themselves.
   */
  Future<void> startCaptureWorkflow() async {
    if (!_alive) return;
    await viewModel.startCaptureWorkflow();
  }

  /* Master DSP switch (the power button on the native home). Persists the
   * flag and pushes it to the engine.
   */
  bool get masterEnabled => viewModel.masterEnabled;

  void updateMasterEnabled(bool enabled) {
    if (!_alive) return;
    viewModel.updateMasterEnabled(enabled);
  }

  /* Last polled processing latency in milliseconds (the VM polls the
   * native engine once per second).
   */
  double get latencyMs => viewModel.processingLatencyMs;

  /* Current audio output device id reported by the native side. */
  String get currentAudioOutput => viewModel.currentAudioOutput;

  /* Name of the currently active script effect in the library ('' when
   * none is loaded).
   */
  String get activeScriptDesc => viewModel.activeScriptDesc;

  /* Compiles the given DSP C script and pushes it to the engine. Returns
   * false when compilation failed (the error is available through
   * viewModel.lastCompileError).
   */
  Future<bool> saveScript(String code) async {
    if (!_alive) return false;
    return viewModel.saveScript(code);
  }

  /* Magnitude response in dB of the device-simulation correction at 256
   * log-spaced points from 20 Hz to 20 kHz, or null when unavailable.
   * Lets a script draw its own response plot.
   */
  Future<List<double>?> getDeviceSimulationFreqResponse() =>
      viewModel.getDeviceSimulationFreqResponse();

  /* Pushes the native settings page (host-provided navigation). */
  void openSettings() {
    if (!_alive) return;
    onOpenSettings?.call();
  }

  /* Opens the system file picker and resolves to the absolute path of the
   * picked file, or '' when the user cancelled. Lets a script obtain e.g.
   * an impulse-response path directly instead of detouring through the
   * settings page. The returned path only reaches the engine through
   * update(), whose own session guard covers post-unload writes.
   */
  Future<String> pickFile({String dialogTitle = ''}) async {
    final result = await FilePicker.pickFiles(
        dialogTitle: dialogTitle.isEmpty ? null : dialogTitle);
    if (result == null || result.files.isEmpty) return '';
    return result.files.first.path ?? '';
  }

  /* PARAM parser bridge: parses the PARAM macros of a DSP C script with
   * the same parser the native editor uses on save. Without arguments the
   * active script's saved source is parsed and merged with the live param
   * values, so a UI script can render exactly the parameter controls the
   * native editor would show, with current values. With an explicit code
   * argument only the parsed definitions (default values) are returned.
   */
  List<ScriptParam> parseParams([String? code]) {
    if (code != null && code.isNotEmpty) return parseScriptParams(code);
    return viewModel.resolveScriptParams();
  }

  /* Clamps and writes one PARAM of the active script by index (index into
   * the list returned by [parseParams]), then pushes the whole list to the
   * engine. The single write path for script params - ScriptParam objects
   * are immutable, scripts never rebuild them themselves.
   */
  Future<void> updateScriptParam(int index, double value) async {
    if (!_alive) return;
    final params = List<ScriptParam>.of(
        viewModel.get<List<ScriptParam>>(ParamID.scriptEffectParams));
    if (index < 0 || index >= params.length) return;
    final p = params[index];
    params[index] = ScriptParam(
        p.name, value.clamp(p.min, p.max).toDouble(),
        min: p.min, max: p.max, step: p.step);
    await viewModel.update(ParamID.scriptEffectParams, params);
  }
}

void registerUiScriptBridges(D4rt interpreter) {
  const lib = uiScriptLibraryUri;

  interpreter.registerBridgedEnum(
      BridgedEnumDefinition<ParamID>(name: 'ParamID', values: ParamID.values), lib);
  interpreter.registerBridgedEnum(BridgedEnumDefinition<MainAxisAlignment>(
      name: 'MainAxisAlignment', values: MainAxisAlignment.values), lib);
  interpreter.registerBridgedEnum(BridgedEnumDefinition<CrossAxisAlignment>(
      name: 'CrossAxisAlignment', values: CrossAxisAlignment.values), lib);
  interpreter.registerBridgedEnum(BridgedEnumDefinition<MainAxisSize>(
      name: 'MainAxisSize', values: MainAxisSize.values), lib);
  interpreter.registerBridgedEnum(BridgedEnumDefinition<TextAlign>(
      name: 'TextAlign', values: TextAlign.values), lib);
  interpreter.registerBridgedEnum(BridgedEnumDefinition<TextOverflow>(
      name: 'TextOverflow', values: TextOverflow.values), lib);
  interpreter.registerBridgedEnum(BridgedEnumDefinition<Brightness>(
      name: 'Brightness', values: Brightness.values), lib);

  /* The Widget base type: needed for the "Widget build(ctx)" entry-point
   * signature and List<Widget> annotations. It cannot be instantiated.
   * D4rt does not know Flutter's class hierarchy, so the subtype function
   * accepts any native Widget instance (Row, Column, ... under a "Widget"
   * annotation).
   */
  registerUiBridge(
      interpreter,
      BridgedClass(
        nativeType: Widget,
        name: 'Widget',
        isSubtypeOfFunc: (value) => value is Widget,
      ),
      lib);

  registerUiBridge(interpreter, _contextBridge(), lib);
  registerUiBridge(interpreter, _colorSchemeBridge(), lib);
  registerUiBridge(interpreter, _colorBridge(), lib);
  registerUiBridge(interpreter, _iconDataBridge(), lib);
  registerUiBridge(interpreter, _iconsBridge(), lib);
  registerUiBridge(interpreter, _fontWeightBridge(), lib);
  registerUiBridge(interpreter, _edgeInsetsBridge(), lib);
  registerUiBridge(interpreter, _borderRadiusBridge(), lib);
  /* Read-only PARAM record produced by ctx.parseParams - scripts read
   * name/value/min/max/step to render script param controls, they never
   * construct or mutate one (writes go through ctx.updateScriptParam).
   */
  registerUiBridge(
      interpreter,
      BridgedClass(
        nativeType: ScriptParam,
        name: 'ScriptParam',
        getters: {
          'name': (visitor, target) => (target as ScriptParam).name,
          'value': (visitor, target) => (target as ScriptParam).value,
          'min': (visitor, target) => (target as ScriptParam).min,
          'max': (visitor, target) => (target as ScriptParam).max,
          'step': (visitor, target) => (target as ScriptParam).step,
        },
      ),
      lib);
  registerUiBridge(interpreter, _alignmentBridge(), lib);
  registerUiBridge(interpreter, _textStyleBridge(), lib);
  registerUiBridge(interpreter, _boxDecorationBridge(), lib);
  registerUiBridge(interpreter, _textBridge(), lib);
  registerUiBridge(interpreter, _iconBridge(), lib);
  registerUiBridge(interpreter, _sizedBoxBridge(), lib);
  registerUiBridge(interpreter, _paddingBridge(), lib);
  registerUiBridge(interpreter, _flexBridges()[0], lib);
  registerUiBridge(interpreter, _flexBridges()[1], lib);
  registerUiBridge(interpreter, _flexBridges()[2], lib);
  registerUiBridge(interpreter, _columnBridge(), lib);
  registerUiBridge(interpreter, _rowBridge(), lib);
  registerUiBridge(interpreter, _stackBridges()[0], lib);
  registerUiBridge(interpreter, _stackBridges()[1], lib);
  registerUiBridge(interpreter, _centerBridge(), lib);
  registerUiBridge(interpreter, _alignBridge(), lib);
  registerUiBridge(interpreter, _containerBridge(), lib);
  registerUiBridge(interpreter, _gestureDetectorBridge(interpreter), lib);
  registerUiBridge(interpreter, _opacityBridge(), lib);
  registerUiBridge(interpreter, _singleChildScrollViewBridge(), lib);
  registerUiBridge(interpreter, _dividerBridge(), lib);
  registerUiBridge(interpreter, _neumorphicButtonBridge(interpreter), lib);
  registerUiBridge(interpreter, _neumorphicSliderBridge(interpreter), lib);
  registerUiBridge(interpreter, _neumorphicToggleBridge(interpreter), lib);
  registerUiBridge(interpreter, _selectorItemBridge(), lib);
  registerUiBridge(interpreter, _neumorphicSelectorBridge(interpreter), lib);
  registerUiBridge(interpreter, _controlCardBridge(interpreter), lib);
  registerUiBridge(interpreter, _genericControlCardBridge(interpreter), lib);
  registerUiBridge(interpreter, _graphicEqPanelBridge(interpreter), lib);
  registerUiBridge(interpreter, _appHeaderBridge(interpreter), lib);
  registerUiBridge(interpreter, _deviceSimulationCardBridge(), lib);
}

// -- argument helpers ---------------------------------------------------------

double _d(Object? v, double fallback) => v is num ? v.toDouble() : fallback;

double? _dOrNull(Object? v) => v is num ? v.toDouble() : null;

int? _iOrNull(Object? v) => v is num ? v.toInt() : null;

String _s(Object? v, String fallback) => v is String ? v : fallback;

bool _b(Object? v, bool fallback) => v is bool ? v : fallback;

bool? _bOrNull(Object? v) => v is bool ? v : null;

/* List elements arrive still wrapped in BridgedInstance (D4rt unwraps
 * top-level arguments only), so every List<bridged type> parameter must
 * unwrap its elements first.
 */
T? _bridgedOf<T>(Object? e) {
  if (e is T) return e;
  if (e is BridgedInstance) {
    final native = e.nativeObject;
    if (native is T) return native as T;
  }
  return null;
}

List<Widget> _widgetList(Object? v) {
  if (v is! List) return const [];
  final result = <Widget>[];
  for (final e in v) {
    final w = _bridgedOf<Widget>(e);
    if (w != null) result.add(w);
  }
  return result;
}

Color? _colorOrNull(Object? v) => _bridgedOf<Color>(v);

/* D4rt unwraps top-level arguments only: values that round-trip through
 * script variables (or sit inside collections) keep arriving wrapped in
 * BridgedInstance. Wrapping every constructor here unwraps the arguments
 * once, so the bridges' plain "is T" / "as T" checks keep working.
 */
Object? _unwrap(Object? v) {
  if (v is BridgedInstance) return v.nativeObject;
  if (v is BridgedEnumValue) return v.nativeValue;
  return v;
}

void registerUiBridge(D4rt interpreter, BridgedClass def, String uri) {
  def.constructors = def.constructors.map((key, ctor) => MapEntry(key,
      (visitor, positionalArgs, namedArgs) => ctor(
          visitor,
          [for (final p in positionalArgs) _unwrap(p)],
          {for (final e in namedArgs.entries) e.key: _unwrap(e.value)})));
  interpreter.registerBridgedClass(def, uri);
}

/* Wraps an interpreted closure so it can be passed to native widget
 * parameters. Interpreted callbacks arrive as InterpretedFunction.
 */
VoidCallback? _voidCallback(D4rt it, Object? fn) => fn == null
    ? null
    : () {
        it.invokeInterpretedFunction(fn as InterpretedFunction, const []);
      };

void Function(bool)? _boolCallback(D4rt it, Object? fn) => fn == null
    ? null
    : (v) {
        it.invokeInterpretedFunction(fn as InterpretedFunction, [v]);
      };

void Function(double)? _doubleCallback(D4rt it, Object? fn) => fn == null
    ? null
    : (v) {
        it.invokeInterpretedFunction(fn as InterpretedFunction, [v]);
      };

void Function(String)? _stringCallback(D4rt it, Object? fn) => fn == null
    ? null
    : (v) {
        it.invokeInterpretedFunction(fn as InterpretedFunction, [v]);
      };

void Function(dynamic)? _dynamicCallback(D4rt it, Object? fn) => fn == null
    ? null
    : (v) {
        it.invokeInterpretedFunction(fn as InterpretedFunction, [v]);
      };

IconData _iconOf(Object? v, IconData fallback) =>
    _bridgedOf<IconData>(v) ?? fallback;

// -- context & theme ----------------------------------------------------------

BridgedClass _contextBridge() {
  return BridgedClass(
    nativeType: UIScriptContext,
    name: 'UIScriptContext',
    getters: {
      'isDark': (visitor, target) => (target as UIScriptContext).isDark,
      'colorScheme': (visitor, target) => (target as UIScriptContext).colorScheme,
      'isCapturing': (visitor, target) => (target as UIScriptContext).isCapturing,
      'masterEnabled': (visitor, target) =>
          (target as UIScriptContext).masterEnabled,
      'latencyMs': (visitor, target) => (target as UIScriptContext).latencyMs,
      'currentAudioOutput': (visitor, target) =>
          (target as UIScriptContext).currentAudioOutput,
      'activeScriptDesc': (visitor, target) =>
          (target as UIScriptContext).activeScriptDesc,
      'viewModel': (visitor, target) => (target as UIScriptContext).viewModel,
    },
    methods: {
      'get': (visitor, target, positionalArgs, namedArgs) {
        if (target is UIScriptContext && positionalArgs.length == 1) {
          /* D4rt hands enum arguments over as BridgedEnumValue wrappers:
           * unwrap before the native cast.
           */
          return target.get(_unwrap(positionalArgs[0]) as ParamID);
        }
        throw ArgumentError('get expects one ParamID argument');
      },
      'update': (visitor, target, positionalArgs, namedArgs) {
        if (target is UIScriptContext && positionalArgs.length == 2) {
          target.update(
              _unwrap(positionalArgs[0]) as ParamID, positionalArgs[1]);
          return null;
        }
        throw ArgumentError('update expects (ParamID, value)');
      },
      'toggleCapture': (visitor, target, positionalArgs, namedArgs) {
        if (target is UIScriptContext) {
          /* Fire-and-forget: the MediaProjection workflow runs on its own. */
          target.toggleCapture();
          return null;
        }
        throw ArgumentError('toggleCapture expects no arguments');
      },
      'startCaptureWorkflow': (visitor, target, positionalArgs, namedArgs) {
        if (target is UIScriptContext) {
          /* Fire-and-forget: syncs status, then may raise the consent
           * dialog; the future only matters for error handling.
           */
          target.startCaptureWorkflow();
          return null;
        }
        throw ArgumentError('startCaptureWorkflow expects no arguments');
      },
      'updateMasterEnabled': (visitor, target, positionalArgs, namedArgs) {
        if (target is UIScriptContext && positionalArgs.length == 1) {
          target.updateMasterEnabled(_unwrap(positionalArgs[0]) as bool);
          return null;
        }
        throw ArgumentError('updateMasterEnabled expects one bool argument');
      },
      'saveScript': (visitor, target, positionalArgs, namedArgs) {
        if (target is UIScriptContext &&
            positionalArgs.length == 1 &&
            positionalArgs[0] is String) {
          /* The Future is returned so scripts can await the compile result. */
          return target.saveScript(positionalArgs[0] as String);
        }
        throw ArgumentError('saveScript expects one String argument');
      },
      'getDeviceSimulationFreqResponse':
          (visitor, target, positionalArgs, namedArgs) {
        if (target is UIScriptContext) {
          return target.getDeviceSimulationFreqResponse();
        }
        throw ArgumentError('getDeviceSimulationFreqResponse expects no arguments');
      },
      'pickFile': (visitor, target, positionalArgs, namedArgs) {
        if (target is UIScriptContext) {
          final title = positionalArgs.isNotEmpty && positionalArgs[0] is String
              ? positionalArgs[0] as String
              : (namedArgs['dialogTitle'] as String? ?? '');
          return target.pickFile(dialogTitle: title);
        }
        throw ArgumentError('pickFile expects an optional String dialog title');
      },
      'parseParams': (visitor, target, positionalArgs, namedArgs) {
        if (target is UIScriptContext &&
            positionalArgs.length <= 1 &&
            (positionalArgs.isEmpty || positionalArgs[0] is String)) {
          return target.parseParams(
              positionalArgs.isEmpty ? null : positionalArgs[0] as String);
        }
        throw ArgumentError('parseParams expects an optional String script code');
      },
      'updateScriptParam': (visitor, target, positionalArgs, namedArgs) {
        if (target is UIScriptContext &&
            positionalArgs.length == 2 &&
            positionalArgs[0] is num &&
            positionalArgs[1] is num) {
          return target.updateScriptParam(
              (positionalArgs[0] as num).toInt(),
              (positionalArgs[1] as num).toDouble());
        }
        throw ArgumentError('updateScriptParam expects (int index, double value)');
      },
      'openSettings': (visitor, target, positionalArgs, namedArgs) {
        if (target is UIScriptContext) {
          target.openSettings();
          return null;
        }
        throw ArgumentError('openSettings expects no arguments');
      },
      'isExpanded': (visitor, target, positionalArgs, namedArgs) {
        if (target is UIScriptContext && positionalArgs.length == 1) {
          return target.isExpanded(positionalArgs[0] as String);
        }
        throw ArgumentError('isExpanded expects one String key');
      },
      'toggleExpanded': (visitor, target, positionalArgs, namedArgs) {
        if (target is UIScriptContext && positionalArgs.length == 1) {
          target.toggleExpanded(positionalArgs[0] as String);
          return null;
        }
        throw ArgumentError('toggleExpanded expects one String key');
      },
    },
  );
}

BridgedClass _colorSchemeBridge() {
  ColorScheme cs(Object target) => target as ColorScheme;
  return BridgedClass(
    nativeType: ColorScheme,
    name: 'ColorScheme',
    getters: {
      'primary': (visitor, target) => cs(target).primary,
      'onPrimary': (visitor, target) => cs(target).onPrimary,
      'secondary': (visitor, target) => cs(target).secondary,
      'onSecondary': (visitor, target) => cs(target).onSecondary,
      'surface': (visitor, target) => cs(target).surface,
      'onSurface': (visitor, target) => cs(target).onSurface,
      'onSurfaceVariant': (visitor, target) => cs(target).onSurfaceVariant,
      'surfaceContainerHighest': (visitor, target) =>
          cs(target).surfaceContainerHighest,
      'error': (visitor, target) => cs(target).error,
      'onError': (visitor, target) => cs(target).onError,
      'outline': (visitor, target) => cs(target).outline,
    },
  );
}

BridgedClass _colorBridge() {
  return BridgedClass(
    nativeType: Color,
    name: 'Color',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) {
        if (positionalArgs.length == 1 && positionalArgs[0] is int) {
          return Color(positionalArgs[0] as int);
        }
        throw ArgumentError('Color expects one int argument');
      },
      'fromARGB': (visitor, positionalArgs, namedArgs) {
        if (positionalArgs.length == 4) {
          return Color.fromARGB(positionalArgs[0] as int,
              positionalArgs[1] as int, positionalArgs[2] as int, positionalArgs[3] as int);
        }
        throw ArgumentError('Color.fromARGB expects 4 int arguments');
      },
      'fromRGBO': (visitor, positionalArgs, namedArgs) {
        if (positionalArgs.length == 4) {
          return Color.fromRGBO(positionalArgs[0] as int, positionalArgs[1] as int,
              positionalArgs[2] as int, _d(positionalArgs[3], 0));
        }
        throw ArgumentError('Color.fromRGBO expects 4 arguments');
      },
    },
    staticGetters: {
      'white': (visitor) => Colors.white,
      'black': (visitor) => Colors.black,
      'transparent': (visitor) => Colors.transparent,
      'red': (visitor) => Colors.red,
      'green': (visitor) => Colors.green,
      'blue': (visitor) => Colors.blue,
      'grey': (visitor) => Colors.grey,
      'amber': (visitor) => Colors.amber,
      'orange': (visitor) => Colors.orange,
    },
    methods: {
      'withValues': (visitor, target, positionalArgs, namedArgs) {
        final color = _bridgedOf<Color>(target);
        if (color != null) {
          return color.withValues(alpha: _d(namedArgs['alpha'], 1.0));
        }
        throw TypeError();
      },
    },
  );
}

/* Type-only bridge: scripts must get icons from the Icons constant table.
 * A runtime IconData constructor would defeat icon font tree-shaking and
 * break the AOT release build (non-constant IconData).
 */
BridgedClass _iconDataBridge() {
  return BridgedClass(
    nativeType: IconData,
    name: 'IconData',
  );
}

/* Curated subset of the Material icon set; exposes the real constants so no
 * code points are duplicated here.
 */
BridgedClass _iconsBridge() {
  return BridgedClass(
    nativeType: Icons,
    name: 'Icons',
    staticGetters: {
      'settings': (visitor) => Icons.settings,
      'close': (visitor) => Icons.close,
      'add': (visitor) => Icons.add,
      'remove': (visitor) => Icons.remove,
      'check': (visitor) => Icons.check,
      'chevronRight': (visitor) => Icons.chevron_right,
      'chevronLeft': (visitor) => Icons.chevron_left,
      'arrowBack': (visitor) => Icons.arrow_back,
      'arrowForward': (visitor) => Icons.arrow_forward,
      'playArrow': (visitor) => Icons.play_arrow,
      'pause': (visitor) => Icons.pause,
      'stop': (visitor) => Icons.stop,
      'skipNext': (visitor) => Icons.skip_next,
      'skipPrevious': (visitor) => Icons.skip_previous,
      'volumeUp': (visitor) => Icons.volume_up,
      'volumeOff': (visitor) => Icons.volume_off,
      'headphones': (visitor) => Icons.headphones,
      'equalizer': (visitor) => Icons.equalizer,
      'graphicEq': (visitor) => Icons.graphic_eq,
      'musicNote': (visitor) => Icons.music_note,
      'home': (visitor) => Icons.home,
      'refresh': (visitor) => Icons.refresh,
      'download': (visitor) => Icons.download,
      'upload': (visitor) => Icons.upload,
      'delete': (visitor) => Icons.delete,
      'edit': (visitor) => Icons.edit,
      'search': (visitor) => Icons.search,
      'moreVert': (visitor) => Icons.more_vert,
      'darkMode': (visitor) => Icons.dark_mode,
      'lightMode': (visitor) => Icons.light_mode,
      'power': (visitor) => Icons.power,
      'star': (visitor) => Icons.star,
      'favorite': (visitor) => Icons.favorite,
      'info': (visitor) => Icons.info,
      'warning': (visitor) => Icons.warning,
      'tune': (visitor) => Icons.tune,
      'palette': (visitor) => Icons.palette,
      'powerSettingsNew': (visitor) => Icons.power_settings_new,
      'lock': (visitor) => Icons.lock,
      'lockOpen': (visitor) => Icons.lock_open,
      'densitySmall': (visitor) => Icons.density_small,
      'arrowUpward': (visitor) => Icons.arrow_upward,
      'arrowDownward': (visitor) => Icons.arrow_downward,
      'arrowLeft': (visitor) => Icons.arrow_left,
      'arrowRight': (visitor) => Icons.arrow_right,
      'arrowDropDown': (visitor) => Icons.arrow_drop_down,
      'arrowDropUp': (visitor) => Icons.arrow_drop_up,
      'expandMore': (visitor) => Icons.expand_more,
      'expandLess': (visitor) => Icons.expand_less,
      'firstPage': (visitor) => Icons.first_page,
      'lastPage': (visitor) => Icons.last_page,
      'keyboardArrowUp': (visitor) => Icons.keyboard_arrow_up,
      'keyboardArrowDown': (visitor) => Icons.keyboard_arrow_down,
      'keyboardArrowLeft': (visitor) => Icons.keyboard_arrow_left,
      'keyboardArrowRight': (visitor) => Icons.keyboard_arrow_right,
      'cancel': (visitor) => Icons.cancel,
      'done': (visitor) => Icons.done,
      'doneAll': (visitor) => Icons.done_all,
      'checkCircle': (visitor) => Icons.check_circle,
      'checkCircleOutline': (visitor) => Icons.check_circle_outline,
      'highlightOff': (visitor) => Icons.highlight_off,
      'radioButtonChecked': (visitor) => Icons.radio_button_checked,
      'radioButtonUnchecked': (visitor) => Icons.radio_button_unchecked,
      'checkBox': (visitor) => Icons.check_box,
      'checkBoxOutlineBlank': (visitor) => Icons.check_box_outline_blank,
      'indeterminateCheckBox': (visitor) => Icons.indeterminate_check_box,
      'toggleOn': (visitor) => Icons.toggle_on,
      'toggleOff': (visitor) => Icons.toggle_off,
      'switchLeft': (visitor) => Icons.switch_left,
      'switchRight': (visitor) => Icons.switch_right,
      'addCircle': (visitor) => Icons.add_circle,
      'removeCircle': (visitor) => Icons.remove_circle,
      'block': (visitor) => Icons.block,
      'fastForward': (visitor) => Icons.fast_forward,
      'fastRewind': (visitor) => Icons.fast_rewind,
      'replay': (visitor) => Icons.replay,
      'repeat': (visitor) => Icons.repeat,
      'repeatOne': (visitor) => Icons.repeat_one,
      'shuffle': (visitor) => Icons.shuffle,
      'loop': (visitor) => Icons.loop,
      'playCircle': (visitor) => Icons.play_circle,
      'pauseCircle': (visitor) => Icons.pause_circle,
      'stopCircle': (visitor) => Icons.stop_circle,
      'mic': (visitor) => Icons.mic,
      'micOff': (visitor) => Icons.mic_off,
      'speaker': (visitor) => Icons.speaker,
      'speakerGroup': (visitor) => Icons.speaker_group,
      'hearing': (visitor) => Icons.hearing,
      'audiotrack': (visitor) => Icons.audiotrack,
      'libraryMusic': (visitor) => Icons.library_music,
      'queueMusic': (visitor) => Icons.queue_music,
      'album': (visitor) => Icons.album,
      'surroundSound': (visitor) => Icons.surround_sound,
      'volumeDown': (visitor) => Icons.volume_down,
      'volumeMute': (visitor) => Icons.volume_mute,
      'deleteForever': (visitor) => Icons.delete_forever,
      'save': (visitor) => Icons.save,
      'folder': (visitor) => Icons.folder,
      'folderOpen': (visitor) => Icons.folder_open,
      'description': (visitor) => Icons.description,
      'contentCopy': (visitor) => Icons.content_copy,
      'contentPaste': (visitor) => Icons.content_paste,
      'contentCut': (visitor) => Icons.content_cut,
      'fileCopy': (visitor) => Icons.file_copy,
      'attachFile': (visitor) => Icons.attach_file,
      'cloud': (visitor) => Icons.cloud,
      'cloudUpload': (visitor) => Icons.cloud_upload,
      'cloudDownload': (visitor) => Icons.cloud_download,
      'dragHandle': (visitor) => Icons.drag_handle,
      'zoomIn': (visitor) => Icons.zoom_in,
      'zoomOut': (visitor) => Icons.zoom_out,
      'filterList': (visitor) => Icons.filter_list,
      'sort': (visitor) => Icons.sort,
      'list': (visitor) => Icons.list,
      'dashboard': (visitor) => Icons.dashboard,
      'widgets': (visitor) => Icons.widgets,
      'apps': (visitor) => Icons.apps,
      'gridView': (visitor) => Icons.grid_view,
      'viewList': (visitor) => Icons.view_list,
      'viewModule': (visitor) => Icons.view_module,
      'layers': (visitor) => Icons.layers,
      'menu': (visitor) => Icons.menu,
      'moreHoriz': (visitor) => Icons.more_horiz,
      'fullscreen': (visitor) => Icons.fullscreen,
      'error': (visitor) => Icons.error,
      'errorOutline': (visitor) => Icons.error_outline,
      'help': (visitor) => Icons.help,
      'helpOutline': (visitor) => Icons.help_outline,
      'priorityHigh': (visitor) => Icons.priority_high,
      'notifications': (visitor) => Icons.notifications,
      'notificationsActive': (visitor) => Icons.notifications_active,
      'notificationsOff': (visitor) => Icons.notifications_off,
      'visibility': (visitor) => Icons.visibility,
      'visibilityOff': (visitor) => Icons.visibility_off,
      'starBorder': (visitor) => Icons.star_border,
      'favoriteBorder': (visitor) => Icons.favorite_border,
      'thumbUp': (visitor) => Icons.thumb_up,
      'thumbDown': (visitor) => Icons.thumb_down,
      'bookmark': (visitor) => Icons.bookmark,
      'bookmarkBorder': (visitor) => Icons.bookmark_border,
      'schedule': (visitor) => Icons.schedule,
      'timer': (visitor) => Icons.timer,
      'hourglassEmpty': (visitor) => Icons.hourglass_empty,
      'hourglassFull': (visitor) => Icons.hourglass_full,
      'history': (visitor) => Icons.history,
      'update': (visitor) => Icons.update,
      'event': (visitor) => Icons.event,
      'calendarMonth': (visitor) => Icons.calendar_month,
      'calendarToday': (visitor) => Icons.calendar_today,
      'alarm': (visitor) => Icons.alarm,
      'accessTime': (visitor) => Icons.access_time,
      'today': (visitor) => Icons.today,
      'batteryFull': (visitor) => Icons.battery_full,
      'batteryStd': (visitor) => Icons.battery_std,
      'bolt': (visitor) => Icons.bolt,
      'wifi': (visitor) => Icons.wifi,
      'wifiOff': (visitor) => Icons.wifi_off,
      'bluetooth': (visitor) => Icons.bluetooth,
      'bluetoothDisabled': (visitor) => Icons.bluetooth_disabled,
      'usb': (visitor) => Icons.usb,
      'sync': (visitor) => Icons.sync,
      'cast': (visitor) => Icons.cast,
      'security': (visitor) => Icons.security,
      'verified': (visitor) => Icons.verified,
      'verifiedUser': (visitor) => Icons.verified_user,
      'person': (visitor) => Icons.person,
      'personOutline': (visitor) => Icons.person_outline,
      'personAdd': (visitor) => Icons.person_add,
      'group': (visitor) => Icons.group,
      'groups': (visitor) => Icons.groups,
      'manageAccounts': (visitor) => Icons.manage_accounts,
      'build': (visitor) => Icons.build,
      'construction': (visitor) => Icons.construction,
      'extension': (visitor) => Icons.extension,
      'memory': (visitor) => Icons.memory,
      'code': (visitor) => Icons.code,
      'terminal': (visitor) => Icons.terminal,
      'storage': (visitor) => Icons.storage,
      'speed': (visitor) => Icons.speed,
      'brightnessHigh': (visitor) => Icons.brightness_high,
      'brightnessLow': (visitor) => Icons.brightness_low,
      'contrast': (visitor) => Icons.contrast,
      'colorLens': (visitor) => Icons.color_lens,
      'place': (visitor) => Icons.place,
      'locationOn': (visitor) => Icons.location_on,
      'myLocation': (visitor) => Icons.my_location,
      'map': (visitor) => Icons.map,
      'navigation': (visitor) => Icons.navigation,
      'explore': (visitor) => Icons.explore,
      'wbSunny': (visitor) => Icons.wb_sunny,
      'waterDrop': (visitor) => Icons.water_drop,
      'air': (visitor) => Icons.air,
      'acUnit': (visitor) => Icons.ac_unit,
      'thermostat': (visitor) => Icons.thermostat,
      'waves': (visitor) => Icons.waves,
      'touchApp': (visitor) => Icons.touch_app,
      'fingerprint': (visitor) => Icons.fingerprint,
      'backHand': (visitor) => Icons.back_hand,
      'share': (visitor) => Icons.share,
      'link': (visitor) => Icons.link,
      'qrCode': (visitor) => Icons.qr_code,
    },
  );
}

BridgedClass _fontWeightBridge() {
  return BridgedClass(
    nativeType: FontWeight,
    name: 'FontWeight',
    staticGetters: {
      'w100': (visitor) => FontWeight.w100,
      'w200': (visitor) => FontWeight.w200,
      'w300': (visitor) => FontWeight.w300,
      'w400': (visitor) => FontWeight.w400,
      'w500': (visitor) => FontWeight.w500,
      'w600': (visitor) => FontWeight.w600,
      'w700': (visitor) => FontWeight.w700,
      'w800': (visitor) => FontWeight.w800,
      'w900': (visitor) => FontWeight.w900,
      'bold': (visitor) => FontWeight.bold,
      'normal': (visitor) => FontWeight.normal,
    },
  );
}

BridgedClass _edgeInsetsBridge() {
  return BridgedClass(
    nativeType: EdgeInsets,
    name: 'EdgeInsets',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) {
        if (positionalArgs.length == 1) {
          return EdgeInsets.all(_d(positionalArgs[0], 0));
        }
        return EdgeInsets.zero;
      },
      'all': (visitor, positionalArgs, namedArgs) =>
          EdgeInsets.all(_d(positionalArgs.isEmpty ? 0 : positionalArgs[0], 0)),
      'symmetric': (visitor, positionalArgs, namedArgs) => EdgeInsets.symmetric(
          vertical: _d(namedArgs['vertical'], 0), horizontal: _d(namedArgs['horizontal'], 0)),
      'only': (visitor, positionalArgs, namedArgs) => EdgeInsets.only(
          left: _d(namedArgs['left'], 0),
          top: _d(namedArgs['top'], 0),
          right: _d(namedArgs['right'], 0),
          bottom: _d(namedArgs['bottom'], 0)),
      'fromLTRB': (visitor, positionalArgs, namedArgs) {
        if (positionalArgs.length == 4) {
          return EdgeInsets.fromLTRB(_d(positionalArgs[0], 0), _d(positionalArgs[1], 0),
              _d(positionalArgs[2], 0), _d(positionalArgs[3], 0));
        }
        throw ArgumentError('EdgeInsets.fromLTRB expects 4 arguments');
      },
    },
    staticGetters: {
      'zero': (visitor) => EdgeInsets.zero,
    },
  );
}

BridgedClass _borderRadiusBridge() {
  return BridgedClass(
    nativeType: BorderRadius,
    name: 'BorderRadius',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) =>
          BorderRadius.circular(_d(positionalArgs.isEmpty ? 0 : positionalArgs[0], 0)),
      'circular': (visitor, positionalArgs, namedArgs) =>
          BorderRadius.circular(_d(positionalArgs.isEmpty ? 0 : positionalArgs[0], 0)),
    },
  );
}

BridgedClass _alignmentBridge() {
  return BridgedClass(
    nativeType: Alignment,
    name: 'Alignment',
    staticGetters: {
      'center': (visitor) => Alignment.center,
      'centerLeft': (visitor) => Alignment.centerLeft,
      'centerRight': (visitor) => Alignment.centerRight,
      'topLeft': (visitor) => Alignment.topLeft,
      'topCenter': (visitor) => Alignment.topCenter,
      'topRight': (visitor) => Alignment.topRight,
      'bottomLeft': (visitor) => Alignment.bottomLeft,
      'bottomCenter': (visitor) => Alignment.bottomCenter,
      'bottomRight': (visitor) => Alignment.bottomRight,
    },
  );
}

BridgedClass _textStyleBridge() {
  return BridgedClass(
    nativeType: TextStyle,
    name: 'TextStyle',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) => TextStyle(
          fontSize: _dOrNull(namedArgs['fontSize']),
          color: _colorOrNull(namedArgs['color']),
          fontWeight: namedArgs['fontWeight'] is FontWeight
              ? namedArgs['fontWeight'] as FontWeight
              : null,
          letterSpacing: _dOrNull(namedArgs['letterSpacing']),
          height: _dOrNull(namedArgs['height'])),
    },
  );
}

BridgedClass _boxDecorationBridge() {
  return BridgedClass(
    nativeType: BoxDecoration,
    name: 'BoxDecoration',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) => BoxDecoration(
          color: _colorOrNull(namedArgs['color']),
          borderRadius: namedArgs['borderRadius'] is BorderRadius
              ? namedArgs['borderRadius'] as BorderRadius
              : null),
    },
  );
}

// -- basic widgets ------------------------------------------------------------

BridgedClass _textBridge() {
  return BridgedClass(
    nativeType: Text,
    name: 'Text',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) {
        if (positionalArgs.length == 1) {
          return Text(_s(positionalArgs[0], ''),
              style: _bridgedOf<TextStyle>(namedArgs['style']),
              textAlign: _bridgedOf<TextAlign>(namedArgs['textAlign']),
              overflow: _bridgedOf<TextOverflow>(namedArgs['overflow']),
              maxLines: _iOrNull(namedArgs['maxLines']));
        }
        throw ArgumentError('Text expects one String argument');
      },
    },
  );
}

BridgedClass _iconBridge() {
  return BridgedClass(
    nativeType: Icon,
    name: 'Icon',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) {
        if (positionalArgs.length == 1) {
          return Icon(_iconOf(positionalArgs[0], Icons.help),
              size: _dOrNull(namedArgs['size']),
              color: _colorOrNull(namedArgs['color']));
        }
        throw ArgumentError('Icon expects one IconData argument');
      },
    },
  );
}

BridgedClass _sizedBoxBridge() {
  return BridgedClass(
    nativeType: SizedBox,
    name: 'SizedBox',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) => SizedBox(
          width: _dOrNull(namedArgs['width']),
          height: _dOrNull(namedArgs['height']),
          child: namedArgs['child'] is Widget
              ? namedArgs['child'] as Widget
              : null),
      'shrink': (visitor, positionalArgs, namedArgs) => SizedBox.shrink(),
    },
  );
}

BridgedClass _paddingBridge() {
  return BridgedClass(
    nativeType: Padding,
    name: 'Padding',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) {
        if (namedArgs['padding'] is EdgeInsets) {
          return Padding(
              padding: namedArgs['padding'] as EdgeInsets,
              child: namedArgs['child'] is Widget ? namedArgs['child'] as Widget : null);
        }
        throw ArgumentError('Padding requires a padding: EdgeInsets argument');
      },
    },
  );
}

List<BridgedClass> _flexBridges() {
  return [
    BridgedClass(
      nativeType: Expanded,
      name: 'Expanded',
      constructors: {
        '': (visitor, positionalArgs, namedArgs) {
          if (namedArgs['child'] is Widget) {
            return Expanded(
                flex: _iOrNull(namedArgs['flex']) ?? 1,
                child: namedArgs['child'] as Widget);
          }
          throw ArgumentError('Expanded requires a child argument');
        },
      },
    ),
    BridgedClass(
      nativeType: Flexible,
      name: 'Flexible',
      constructors: {
        '': (visitor, positionalArgs, namedArgs) {
          if (namedArgs['child'] is Widget) {
            return Flexible(
                flex: _iOrNull(namedArgs['flex']) ?? 1,
                child: namedArgs['child'] as Widget);
          }
          throw ArgumentError('Flexible requires a child argument');
        },
      },
    ),
    BridgedClass(
      nativeType: Spacer,
      name: 'Spacer',
      constructors: {
        '': (visitor, positionalArgs, namedArgs) =>
            Spacer(flex: _iOrNull(namedArgs['flex']) ?? 1),
      },
    ),
  ];
}

Map<String, Object?> _flexParams(Map<String, Object?> namedArgs) => {
      'mainAxisAlignment': namedArgs['mainAxisAlignment'] is MainAxisAlignment
          ? namedArgs['mainAxisAlignment'] as MainAxisAlignment
          : MainAxisAlignment.start,
      'crossAxisAlignment': namedArgs['crossAxisAlignment'] is CrossAxisAlignment
          ? namedArgs['crossAxisAlignment'] as CrossAxisAlignment
          : CrossAxisAlignment.center,
      'mainAxisSize': namedArgs['mainAxisSize'] is MainAxisSize
          ? namedArgs['mainAxisSize'] as MainAxisSize
          : MainAxisSize.max,
    };

BridgedClass _columnBridge() {
  return BridgedClass(
    nativeType: Column,
    name: 'Column',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) {
        final p = _flexParams(namedArgs);
        return Column(
            mainAxisAlignment: p['mainAxisAlignment'] as MainAxisAlignment,
            crossAxisAlignment: p['crossAxisAlignment'] as CrossAxisAlignment,
            mainAxisSize: p['mainAxisSize'] as MainAxisSize,
            children: _widgetList(namedArgs['children']));
      },
    },
  );
}

BridgedClass _rowBridge() {
  return BridgedClass(
    nativeType: Row,
    name: 'Row',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) {
        final p = _flexParams(namedArgs);
        return Row(
            mainAxisAlignment: p['mainAxisAlignment'] as MainAxisAlignment,
            crossAxisAlignment: p['crossAxisAlignment'] as CrossAxisAlignment,
            mainAxisSize: p['mainAxisSize'] as MainAxisSize,
            children: _widgetList(namedArgs['children']));
      },
    },
  );
}

List<BridgedClass> _stackBridges() {
  return [
    BridgedClass(
      nativeType: Stack,
      name: 'Stack',
      constructors: {
        '': (visitor, positionalArgs, namedArgs) => Stack(
            alignment: namedArgs['alignment'] is Alignment
                ? namedArgs['alignment'] as Alignment
                : AlignmentDirectional.topStart,
            children: _widgetList(namedArgs['children'])),
      },
    ),
    BridgedClass(
      nativeType: Positioned,
      name: 'Positioned',
      constructors: {
        '': (visitor, positionalArgs, namedArgs) {
          if (namedArgs['child'] is Widget) {
            return Positioned(
                left: _dOrNull(namedArgs['left']),
                top: _dOrNull(namedArgs['top']),
                right: _dOrNull(namedArgs['right']),
                bottom: _dOrNull(namedArgs['bottom']),
                width: _dOrNull(namedArgs['width']),
                height: _dOrNull(namedArgs['height']),
                child: namedArgs['child'] as Widget);
          }
          throw ArgumentError('Positioned requires a child argument');
        },
      },
    ),
  ];
}

BridgedClass _centerBridge() {
  return BridgedClass(
    nativeType: Center,
    name: 'Center',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) => Center(
          child: namedArgs['child'] is Widget ? namedArgs['child'] as Widget : null),
    },
  );
}

BridgedClass _alignBridge() {
  return BridgedClass(
    nativeType: Align,
    name: 'Align',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) => Align(
          alignment: namedArgs['alignment'] is Alignment
              ? namedArgs['alignment'] as Alignment
              : Alignment.center,
          child: namedArgs['child'] is Widget ? namedArgs['child'] as Widget : null),
    },
  );
}

BridgedClass _containerBridge() {
  return BridgedClass(
    nativeType: Container,
    name: 'Container',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) => Container(
          width: _dOrNull(namedArgs['width']),
          height: _dOrNull(namedArgs['height']),
          color: _colorOrNull(namedArgs['color']),
          padding: _bridgedOf<EdgeInsets>(namedArgs['padding']),
          alignment: _bridgedOf<AlignmentGeometry>(namedArgs['alignment']),
          decoration: _bridgedOf<BoxDecoration>(namedArgs['decoration']),
          child: _bridgedOf<Widget>(namedArgs['child']),
        ),
    },
  );
}

BridgedClass _gestureDetectorBridge(D4rt it) {
  return BridgedClass(
    nativeType: GestureDetector,
    name: 'GestureDetector',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) {
        if (namedArgs['child'] is Widget) {
          return GestureDetector(
              onTap: _voidCallback(it, namedArgs['onTap']),
              behavior: HitTestBehavior.opaque,
              child: namedArgs['child'] as Widget);
        }
        throw ArgumentError('GestureDetector requires a child argument');
      },
    },
  );
}

BridgedClass _opacityBridge() {
  return BridgedClass(
    nativeType: Opacity,
    name: 'Opacity',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) {
        if (namedArgs['child'] is Widget) {
          return Opacity(
              opacity: _d(namedArgs['opacity'], 1.0),
              child: namedArgs['child'] as Widget);
        }
        throw ArgumentError('Opacity requires a child argument');
      },
    },
  );
}

BridgedClass _singleChildScrollViewBridge() {
  return BridgedClass(
    nativeType: SingleChildScrollView,
    name: 'SingleChildScrollView',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) {
        if (namedArgs['child'] is Widget) {
          return SingleChildScrollView(
              padding: namedArgs['padding'] is EdgeInsets
                  ? namedArgs['padding'] as EdgeInsets
                  : null,
              child: namedArgs['child'] as Widget);
        }
        throw ArgumentError('SingleChildScrollView requires a child argument');
      },
    },
  );
}

BridgedClass _dividerBridge() {
  return BridgedClass(
    nativeType: Divider,
    name: 'Divider',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) => Divider(
          height: _dOrNull(namedArgs['height']),
          thickness: _dOrNull(namedArgs['thickness']),
          indent: _dOrNull(namedArgs['indent']),
          endIndent: _dOrNull(namedArgs['endIndent']),
          color: _colorOrNull(namedArgs['color'])),
    },
  );
}

// -- wecho components ---------------------------------------------------------

BridgedClass _neumorphicButtonBridge(D4rt it) {
  return BridgedClass(
    nativeType: NeumorphicButton,
    name: 'NeumorphicButton',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) => NeumorphicButton(
          onTap: _voidCallback(it, namedArgs['onTap']),
          enabled: _b(namedArgs['enabled'], true),
          padding: namedArgs['padding'] is EdgeInsets
              ? namedArgs['padding'] as EdgeInsets
              : const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          borderRadius: _d(namedArgs['borderRadius'], 12),
          children: _widgetList(namedArgs['children'])),
    },
  );
}

BridgedClass _neumorphicSliderBridge(D4rt it) {
  return BridgedClass(
    nativeType: NeumorphicSlider,
    name: 'NeumorphicSlider',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) {
        final onChanged = _doubleCallback(it, namedArgs['onChanged']);
        return NeumorphicSlider(
            label: _s(namedArgs['label'], ''),
            value: _d(namedArgs['value'], 0),
            min: _d(namedArgs['min'], 0),
            max: _d(namedArgs['max'], 1),
            unit: _s(namedArgs['unit'], ''),
            divisions: _iOrNull(namedArgs['divisions']),
            /* Each drag tick opens the interaction window: the slider
             * renders the drag itself while the root suspends full
             * rebuilds (they would only stall the main thread).
             */
            onChanged: onChanged == null
                ? null
                : (v) {
                    CustomUiManager.beginInteraction();
                    onChanged(v);
                  },
            enabled: _b(namedArgs['enabled'], true),
            showDivider: _b(namedArgs['showDivider'], true));
      },
    },
  );
}

BridgedClass _neumorphicToggleBridge(D4rt it) {
  return BridgedClass(
    nativeType: NeumorphicToggle,
    name: 'NeumorphicToggle',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) => NeumorphicToggle(
          label: _s(namedArgs['label'], ''),
          value: _b(namedArgs['value'], false),
          onChanged: _boolCallback(it, namedArgs['onChanged']),
          enabled: _b(namedArgs['enabled'], true)),
    },
  );
}

BridgedClass _selectorItemBridge() {
  return BridgedClass(
    nativeType: SelectorItem<dynamic>,
    name: 'SelectorItem',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) => SelectorItem<dynamic>(
          value: namedArgs['value'],
          label: _s(namedArgs['label'], ''),
          deletable: _b(namedArgs['deletable'], false)),
    },
  );
}

BridgedClass _neumorphicSelectorBridge(D4rt it) {
  return BridgedClass(
    nativeType: NeumorphicSelector<dynamic>,
    name: 'NeumorphicSelector',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) => NeumorphicSelector<dynamic>(
          items: namedArgs['items'] is List
              ? [for (final e in namedArgs['items'] as List)
                  ?_bridgedOf<SelectorItem<dynamic>>(e)]
              : const <SelectorItem<dynamic>>[],
          selectedValue: namedArgs['selectedValue'],
          onSelect: _dynamicCallback(it, namedArgs['onSelect']),
          onDelete: _dynamicCallback(it, namedArgs['onDelete']),
          enabled: _b(namedArgs['enabled'], true),
          hint: _s(namedArgs['hint'], 'Select')),
    },
  );
}

BridgedClass _controlCardBridge(D4rt it) {
  return BridgedClass(
    nativeType: ControlCard,
    name: 'ControlCard',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) {
        final cardIcon = _bridgedOf<IconData>(namedArgs['icon']);
        if (cardIcon != null &&
            namedArgs['title'] is String &&
            namedArgs['description'] is String &&
            namedArgs['onToggleExpand'] != null &&
            namedArgs['onChanged'] != null) {
          return ControlCard(
              icon: cardIcon,
              title: namedArgs['title'] as String,
              description: namedArgs['description'] as String,
              value: _d(namedArgs['value'], 0),
              min: _d(namedArgs['min'], 0),
              max: _d(namedArgs['max'], 1),
              unit: _s(namedArgs['unit'], ''),
              expanded: _b(namedArgs['expanded'], false),
              onToggleExpand: _voidCallback(it, namedArgs['onToggleExpand'])!,
              onChanged: _doubleCallback(it, namedArgs['onChanged'])!);
        }
        throw ArgumentError(
            'ControlCard requires icon, title, description, onToggleExpand, onChanged');
      },
    },
  );
}

BridgedClass _genericControlCardBridge(D4rt it) {
  return BridgedClass(
    nativeType: GenericControlCard,
    name: 'GenericControlCard',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) {
        final cardIcon = _bridgedOf<IconData>(namedArgs['icon']);
        if (cardIcon != null &&
            namedArgs['title'] is String &&
            namedArgs['description'] is String &&
            namedArgs['onToggle'] != null) {
          return GenericControlCard(
              icon: cardIcon,
              title: namedArgs['title'] as String,
              subtitle: _s(namedArgs['subtitle'], ''),
              description: namedArgs['description'] as String,
              enabled: _b(namedArgs['enabled'], true),
              expanded: _bOrNull(namedArgs['expanded']),
              onToggleExpand: _voidCallback(it, namedArgs['onToggleExpand']),
              onToggle: _boolCallback(it, namedArgs['onToggle'])!,
              children: _widgetList(namedArgs['children']));
        }
        throw ArgumentError(
            'GenericControlCard requires icon, title, description, onToggle');
      },
    },
  );
}

// -- full host panels ---------------------------------------------------------

/* Constant-instance cache for the heavy host panels: every script state
 * change rebuilds the whole interpreted tree, and constructing these panels
 * again with identical inputs makes Flutter re-run their full internal
 * build for nothing. When the inputs match, the previous widget instance is
 * returned so Flutter skips the subtree update entirely. The cache is
 * invalidated on script reload (generation) - a stale instance would carry
 * dead interpreter callbacks. The cached callback of a reused instance is
 * never invoked for stale inputs, because a callback only fires after the
 * corresponding config actually changed.
 */
Widget? _cachedEqPanel;
String? _cachedEqKey;
int? _cachedEqGeneration;

Widget? _cachedDeviceCard;
int? _cachedDeviceCardGeneration;

/* The complete IIR equalizer panel: drag-to-fit response plot, presets,
 * band count, preamp and a per-band editor. [config] is the
 * ParamID.iirEqualizerEffectConfig string; the whole edited config comes
 * back through onConfigChanged.
 */
BridgedClass _graphicEqPanelBridge(D4rt it) {
  return BridgedClass(
    nativeType: GraphicEqPanel,
    name: 'GraphicEqPanel',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) {
        if (namedArgs['config'] is String &&
            namedArgs['onConfigChanged'] != null) {
          final config = namedArgs['config'] as String;
          final enabled = _b(namedArgs['enabled'], true);
          final generation = CustomUiManager.currentGeneration;
          final key = '$config|\x1f$enabled';
          if (_cachedEqPanel != null &&
              _cachedEqGeneration == generation &&
              _cachedEqKey == key) {
            return _cachedEqPanel!;
          }
          _cachedEqGeneration = generation;
          _cachedEqKey = key;
          _cachedEqPanel = GraphicEqPanel(
              config: config,
              onConfigChanged: _stringCallback(it, namedArgs['onConfigChanged'])!,
              enabled: enabled);
          return _cachedEqPanel!;
        }
        throw ArgumentError(
            'GraphicEqPanel requires config: String and onConfigChanged');
      },
    },
  );
}

/* The native title bar: WEcho title, capture status and latency readouts,
 * settings entry. Callbacks are optional.
 */
BridgedClass _appHeaderBridge(D4rt it) {
  return BridgedClass(
    nativeType: AppHeader,
    name: 'AppHeader',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) => AppHeader(
          onSettingsPressed: _voidCallback(it, namedArgs['onSettingsPressed']),
          onCapturePressed: _voidCallback(it, namedArgs['onCapturePressed']),
          isCapturing: _b(namedArgs['isCapturing'], false),
          showCaptureButton: _b(namedArgs['showCaptureButton'], true),
          processingLatencyMs: _d(namedArgs['processingLatencyMs'], 0)),
    },
  );
}

/* The full device-simulation card (current/target device pickers, search,
 * response plot, apply). Self-contained: it talks to the view model
 * directly. Always pass ctx.viewModel.
 */
BridgedClass _deviceSimulationCardBridge() {
  return BridgedClass(
    nativeType: DeviceSimulationCard,
    name: 'DeviceSimulationCard',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) {
        final vm = _bridgedOf<DSPControllerViewModel>(namedArgs['viewModel']);
        if (vm != null) {
          /* Self-contained card (no interpreter callbacks): reuse the
           * instance while the script session lives.
           */
          final generation = CustomUiManager.currentGeneration;
          if (_cachedDeviceCard != null &&
              _cachedDeviceCardGeneration == generation) {
            return _cachedDeviceCard!;
          }
          _cachedDeviceCardGeneration = generation;
          _cachedDeviceCard = DeviceSimulationCard(viewModel: vm);
          return _cachedDeviceCard!;
        }
        throw ArgumentError(
            'DeviceSimulationCard requires viewModel: ctx.viewModel');
      },
    },
  );
}
