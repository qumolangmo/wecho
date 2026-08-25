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

import 'dart:convert';
import 'dart:typed_data';

enum OutputMode {
  speaker,
  headphone,
  disabled,
}

enum EQFilterType { pk, lsc, hsc }

extension EQFilterTypeX on EQFilterType {
  String get label {
    switch (this) {
      case EQFilterType.pk: return 'PK';
      case EQFilterType.lsc: return 'LSC';
      case EQFilterType.hsc: return 'HSC';
    }
  }

  static EQFilterType fromLabel(String s) {
    switch (s.toUpperCase()) {
      case 'LSC': return EQFilterType.lsc;
      case 'HSC': return EQFilterType.hsc;
      default: return EQFilterType.pk;
    }
  }
}

class EQFilter {
  final bool enabled;
  final EQFilterType type;
  final int fc;       // Hz
  final double gain;  // dB
  final double q;

  const EQFilter({
    this.enabled = true,
    this.type = EQFilterType.pk,
    this.fc = 1000,
    this.gain = 0,
    this.q = 1.0,
  });

  EQFilter copyWith({bool? enabled, EQFilterType? type, int? fc, double? gain, double? q}) {
    return EQFilter(
      enabled: enabled ?? this.enabled,
      type: type ?? this.type,
      fc: fc ?? this.fc,
      gain: gain ?? this.gain,
      q: q ?? this.q,
    );
  }
}

class IIREqualizerConfig {
  final double preamp;        // dB
  final List<EQFilter> filters;

  const IIREqualizerConfig({this.preamp = 0, this.filters = const []});

  IIREqualizerConfig copyWith({double? preamp, List<EQFilter>? filters}) {
    return IIREqualizerConfig(
      preamp: preamp ?? this.preamp,
      filters: filters ?? this.filters,
    );
  }

  String toParamString() {
    final sb = StringBuffer();
    sb.writeln('Preamp: ${_fmt(preamp)} dB');
    for (int i = 0; i < filters.length; i++) {
      final f = filters[i];
      sb.writeln('Filter ${i + 1}: ${f.enabled ? "ON" : "OFF"} ${f.type.label} '
          'Fc ${f.fc} Hz Gain ${_fmt(f.gain)} dB Q ${_fmt(f.q)}');
    }
    return sb.toString().trimRight();
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  static IIREqualizerConfig fromParamString(String text) {
    double preamp = 0;
    final filters = <EQFilter>[];
    final preampRe = RegExp(r'^Preamp:\s*(-?\d+(?:\.\d+)?)\s*dB', caseSensitive: false);
    final filterRe = RegExp(
        r'^Filter\s+\d+\s*:\s*(ON|OFF)\s+(\w+)\s+Fc\s+(\d+)\s*Hz\s+Gain\s+(-?\d+(?:\.\d+)?)\s*dB\s+Q\s+(\d+(?:\.\d+)?)',
        caseSensitive: false);
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final pm = preampRe.firstMatch(line);
      if (pm != null) {
        preamp = double.tryParse(pm.group(1)!) ?? 0;
        continue;
      }
      final fm = filterRe.firstMatch(line);
      if (fm != null) {
        filters.add(EQFilter(
          enabled: fm.group(1)!.toUpperCase() == 'ON',
          type: EQFilterTypeX.fromLabel(fm.group(2)!),
          fc: int.tryParse(fm.group(3)!) ?? 1000,
          gain: double.tryParse(fm.group(4)!) ?? 0,
          q: double.tryParse(fm.group(5)!) ?? 1.0,
        ));
      }
    }
    return IIREqualizerConfig(preamp: preamp, filters: filters);
  }
}

const String kDefaultIIREqualizerParamString = '''Preamp: 0.0 dB
Filter 1: ON PK Fc 31 Hz Gain 0.0 dB Q 1.00
Filter 2: ON PK Fc 62 Hz Gain 0.0 dB Q 1.00
Filter 3: ON PK Fc 125 Hz Gain 0.0 dB Q 1.00
Filter 4: ON PK Fc 250 Hz Gain 0.0 dB Q 1.00
Filter 5: ON PK Fc 500 Hz Gain 0.0 dB Q 1.00
Filter 6: ON PK Fc 1000 Hz Gain 0.0 dB Q 1.00
Filter 7: ON PK Fc 2000 Hz Gain 0.0 dB Q 1.00
Filter 8: ON PK Fc 4000 Hz Gain 0.0 dB Q 1.00
Filter 9: ON PK Fc 8000 Hz Gain 0.0 dB Q 1.00
Filter 10: ON PK Fc 16000 Hz Gain 0.0 dB Q 1.00''';

Uint8List serializeScriptParams(List<ScriptParam> params) {
  final ByteData data = ByteData(16 * 68); // always 16 entries: name[64] + value(4)
  for (int i = 0; i < 16; i++) {
    if (i < params.length) {
      final nameBytes = params[i].name.codeUnits;
      final nameLen = nameBytes.length < 64 ? nameBytes.length : 63;
      for (int j = 0; j < nameLen; j++) {
        data.setUint8(i * 68 + j, nameBytes[j]);
      }
      data.setFloat32(i * 68 + 64, params[i].value, Endian.host);
    }
  }
  return data.buffer.asUint8List();
}

class ScriptParam {
  final String name;
  final double value;
  final double min;
  final double max;
  final double step;

  factory ScriptParam(String name, double value, {double min = 0, double max = 10, double step = 0.1}) {
    if (min > max) {
      final tmp = min;
      min = max;
      max = tmp;
    }

    if (value < min) value = min;
    if (value > max) value = max;
    if (step <= 0) step = 0.1;

    return ScriptParam._(name, value, min, max, step);
  }

  const ScriptParam._(this.name, this.value, this.min, this.max, this.step);

  Map<String, dynamic> toJson() => {
    'name': name, 'value': value, 'min': min, 'max': max, 'step': step,
  };

  factory ScriptParam.fromJson(Map<String, dynamic> json) => ScriptParam(
    json['name'] as String,
    (json['value'] as num).toDouble(),
    min: (json['min'] as num?)?.toDouble() ?? 0,
    max: (json['max'] as num?)?.toDouble() ?? 10,
    step: (json['step'] as num?)?.toDouble() ?? 0.1,
  );
}

String parseScriptDesc(String code) {
  final match = RegExp(r'^//\s*@desc\s*:\s*(.+)', multiLine: false).firstMatch(code);

  final desc = match != null ? match.group(1)!.trim() : 'wecho实时编程脚本';

  // 映射常见英文描述为中文，不修改模板代码
  if (desc == 'Script Effect' ||
      desc == 'not found desc.' ||
      desc.toLowerCase().contains('script effect')) {
    return 'wecho实时编程脚本';
  }

  return desc;
}

/// Check if script code calls new_*() allocation functions inside run().
/// Returns a list of violating function names, or empty list if valid.
/// Calls inside comments (// or /* */) are ignored.
List<String> checkNewInRun(String code) {
  // Extract the body of run() function
  final runMatch = RegExp(r'\bvoid\s+run\s*\([^)]*\)\s*\{').firstMatch(code);
  if (runMatch == null) return [];

  // Find the opening brace position, then match braces to find the body
  int start = runMatch.end - 1; // position of '{'
  int depth = 0;
  int end = start;
  for (int i = start; i < code.length; i++) {
    if (code[i] == '{') {
      depth++;
    }
    else if (code[i] == '}') {
      depth--;
      if (depth == 0) { end = i; break; }
    }
  }

  final runBody = code.substring(start, end + 1);
  // Strip comments before checking
  final stripped = _stripComments(runBody);
  final allocFuncs = ['new_biquad', 'new_delay_line', 'new_convolver', 'new_harmonic'];
  final violations = <String>[];

  for (final func in allocFuncs) {
    if (RegExp('\\b${func}\\s*\\(').hasMatch(stripped)) {
      violations.add(func);
    }
  }

  return violations;
}

/// Strip both // single-line and /* */ multi-line comments from C code.
String _stripComments(String code) {
  final buf = StringBuffer();
  int i = 0;
  while (i < code.length) {
    if (i + 1 < code.length && code[i] == '/' && code[i + 1] == '/') {
      // Single-line comment: skip until newline
      i += 2;
      while (i < code.length && code[i] != '\n') i++;
    } else if (i + 1 < code.length && code[i] == '/' && code[i + 1] == '*') {
      // Multi-line comment: skip until */
      i += 2;
      while (i + 1 < code.length && !(code[i] == '*' && code[i + 1] == '/')) i++;
      if (i + 1 < code.length) i += 2;
    } else {
      buf.write(code[i]);
      i++;
    }
  }
  return buf.toString();
}

List<ScriptParam> parseScriptParams(String code) {
  // Pattern 1: // @min=, max=, step=, [name=] \n type var = val
  final regexLine = RegExp(
    r'//\s*@min\s*=\s*([\d.eE+-]+)\s*,\s*max\s*=\s*([\d.eE+-]+)\s*,\s*step\s*=\s*([\d.eE+-]+)(?:\s*,\s*name\s*=\s*([^\s,]+))?\s*\n\s*(?:float|int|double)\s+(\w+)\s*=\s*([\d.eE+-]+)',
    multiLine: true,
  );
  // Pattern 2: PARAM(var, min, max, step, value, "display_name")
  final regexParam = RegExp(
    r'PARAM\s*\(\s*(\w+)\s*,\s*([\d.eE+-]+)\s*,\s*([\d.eE+-]+)\s*,\s*([\d.eE+-]+)\s*,\s*([\d.eE+-]+)\s*,\s*"([^"]*)"\s*\)',
    multiLine: true,
  );

  final params = <ScriptParam>[];
  final seen = <String>{};

  for (final m in regexLine.allMatches(code)) {
    final name = m.group(4) ?? m.group(5)!;
    final p = ScriptParam(
      name,
      double.parse(m.group(6)!),
      min: double.parse(m.group(1)!),
      max: double.parse(m.group(2)!),
      step: double.parse(m.group(3)!),
    );
    if (seen.add(p.name)) params.add(p);
  }

  for (final m in regexParam.allMatches(code)) {
    final varName = m.group(1)!;
    final displayName = m.group(6)!.isNotEmpty ? m.group(6)! : varName;
    final p = ScriptParam(
      displayName,
      double.parse(m.group(5)!),
      min: double.parse(m.group(2)!),
      max: double.parse(m.group(3)!),
      step: double.parse(m.group(4)!),
    );
    if (seen.add(p.name)) params.add(p);
  }

  return params;
}

enum ParamID {
  dspEnabled(bool),
  gainEffectGain(double),
  balanceEffectBalance(double),
  bassEffectEnabled(bool),
  bassEffectGain(int),
  bassEffectCenterFreq(int),
  bassEffectQ(double),
  clarityEffectEnabled(bool),
  clarityEffectGain(int),
  evenHarmonicEffectEnabled(bool),
  evenHarmonicEffectBase(double),
  evenHarmonicEffectWarm(double),
  evenHarmonicEffectSugar(double),
  convolveEffectEnabled(bool),
  convolveEffectMix(double),
  convolveEffectIrPath(String),
  convolveEffectIrData(String),
  compressorEffectEnabled(bool),
  compressorEffectThreshold(int),
  compressorEffectRatio(int),
  compressorEffectMakeupGain(int),
  compressorEffectAttack(int),
  compressorEffectRelease(int),
  lookAheadSoftLimitEffectEnabled(bool),
  lowcatEffectEnabled(bool),
  lowcatEffectCutoffFrequency(int),
  iirEqualizerEffectEnabled(bool),
  iirEqualizerEffectConfig(String),
  virtualbassEffectEnabled(bool),
  virtualbassEffectEnvelopeRate(int),
  virtualbassEffectMidGain(double),
  virtualbassEffectHighGain(double),
  virtualbassEffectHarmonicGain(double),
  reverbEffectEnabled(bool),
  reverbEffectRoomSize(double),
  reverbEffectDamping(double),
  reverbEffectMix(double),
  reverbEffectStereoWidth(double),
  reverbEffectModDepth(double),
  reverbEffectModFreq(double),
  reverbEffectPreDelay(int),
  reverbEffectMatrixType(int),
  scriptEffectEnabled(bool),
  scriptEffectParams(List<ScriptParam>),
  scriptEffectCode(String),
  diffSurroundingEffectEnabled(bool),
  diffSurroundingEffectDelayMs(int),
  viperReverbEffectEnabled(bool),
  viperReverbEffectRoomSize(double),
  viperReverbEffectWidth(double),
  viperReverbEffectDamp(double),
  viperReverbEffectWet(double),
  viperReverbEffectDry(double),
  viperReverbEffectMode(int);

  final Type type;

  const ParamID(this.type);
}

const String kDefaultScriptCode = '''
// @desc: wecho dsp template code (don't override this code)
float ll = 0, rr = 0;

PARAM(gain, 0, 1.8, 0.1, 1.0, "增益");

Biquad_ hp_l, hp_r;

const int sample_rate = SAMPLE_RATE;
const int samples_per_channel = SAMPLES_PER_CHANNEL;

void setParams(ScriptParams* params) {
    gain = params[0].value;
    // init filter state here.

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

/* readme first:
  1. this script must begin with "// @desc: script name".
  2. all adjustable params must be defined with macro PARAM(). flutter will match the regex to set the ui state. SAMPLE_RATE and SAMPLES_PER_CHANNEL are per-defined macros.
  3. you must init all filter state and other params in setParams(). (max 16 PARAM())
  4. memcpy, memset are safe to use. other lib functions are not tested.
  5. (warning for llm) all the getter functions are focus on mono channel(convolver for stereo channel). so you must use at least 2 items to process stereo audio.
  6. (warning for llm) do not apply your soft limiter code in this script.
  7. new_biquad/new_delay_line/new_convolver/new_harmonic must only be called from setParams(). Calling them from run() causes memory leak. Allocated objects are managed by GC, no need to free them manually.
*/

/* valid api functions

  float sinf(float x);
  float sinhf(float x);
  float cosf(float x);
  float coshf(float x);
  float tanf(float x);
  float tanhf(float x);
  float atanf(float x);
  float atanhf(float x);
  float expf(float x);
  float logf(float x);
  float log2f(float x);
  float log10f(float x);
  float powf(float x, float y);
  float sqrtf(float x);
  float fabsf(float x);
  float fmodf(float x, float y);
  float floorf(float x);
  float ceilf(float x);
  float fminf(float x, float y);
  float fmaxf(float x, float y);

  Biquad_ new_biquad();
  void biquad_reset(Biquad_ ctx);
  void biquad_set_hp(Biquad_ ctx, float cutoff, float q);
  void biquad_set_lp(Biquad_ ctx, float cutoff, float q);
  void biquad_set_ls(Biquad_ ctx, float cutoff, float q, float gain);
  void biquad_set_hs(Biquad_ ctx, float cutoff, float q, float gain);
  void biquad_set_peak(Biquad_ ctx, float cutoff, float q, float gain);
  void biquad_set_coeffs(Biquad_ ctx, double a0, double a1, double a2, double b0, double b1, double b2);
  float biquad_process(Biquad_ ctx, float input);
  void biquad_process_block(Biquad_ ctx, float* input, float* output);

  DelayLine_ new_delay_line();
  void delay_line_reset(DelayLine_ ctx);
  void delay_line_set_delay(DelayLine_ ctx, int samples); // max delay samples: 8192
  float delay_line_process(DelayLine_ ctx, float input); // push and pop a sample from delay line
  void delay_line_process_block(DelayLine_ ctx, float* input, float* output); // process a block of samples from delay line
  float delay_line_read(DelayLine_ ctx); // just read a sample from delay line without push
  void delay_line_read_block(DelayLine_ ctx, float* output); // just read a block of samples from delay line without push
  void delay_line_write(DelayLine_ ctx, float input); // just write a sample to delay line without pop
  void delay_line_write_block(DelayLine_ ctx, float* input); // just write a block of samples to delay line without pop

  Convolver_ new_convolver();
  void convolver_reset(Convolver_ ctx);
  void convolver_set_ir(Convolver_ ctx, float* ir_l, float* ir_r, int samples);
  void convolver_set_ir_path(Convolver_ ctx, const char* path);
  void convolver_process_block(Convolver_ ctx, float* input_l, float* input_r, float* output_l, float* output_r);

  Harmonic_ new_harmonic();
  void harmonic_reset(Harmonic_ ctx);
  void harmonic_set_coeffs(Harmonic_ ctx, float base, float order2, float order3, float order4, float order5, float order6, float order7, float order8);
  float harmonic_process(Harmonic_ ctx, float input);
  void harmonic_process_block(Harmonic_ ctx, float* input, float* output);
*/
''';

class AudioConfig {
  final Map<ParamID, dynamic> _values;

  AudioConfig([Map<ParamID, dynamic>? values])
      : _values = values ?? _defaultValues;

  static final Map<ParamID, dynamic> _defaultValues = {
    ParamID.dspEnabled: true,
    ParamID.gainEffectGain: 0.0,
    ParamID.balanceEffectBalance: 0.0,
    ParamID.bassEffectEnabled: false,
    ParamID.bassEffectGain: 0,
    ParamID.bassEffectCenterFreq: 60,
    ParamID.bassEffectQ: 0.6,
    ParamID.clarityEffectEnabled: false,
    ParamID.clarityEffectGain: 0,
    ParamID.evenHarmonicEffectEnabled: false,
    ParamID.evenHarmonicEffectBase: 0.0,
    ParamID.evenHarmonicEffectWarm: 0.0,
    ParamID.evenHarmonicEffectSugar: 0.0,
    ParamID.convolveEffectEnabled: false,
    ParamID.convolveEffectMix: 0.5,
    ParamID.convolveEffectIrPath: '',
    ParamID.convolveEffectIrData: '',
    ParamID.compressorEffectEnabled: false,
    ParamID.compressorEffectThreshold: 0,
    ParamID.compressorEffectRatio: 1,
    ParamID.compressorEffectMakeupGain: 1,
    ParamID.compressorEffectAttack: 2,
    ParamID.compressorEffectRelease: 2,
    ParamID.lookAheadSoftLimitEffectEnabled: false,
    ParamID.lowcatEffectEnabled: false,
    ParamID.lowcatEffectCutoffFrequency: 120,
    ParamID.iirEqualizerEffectConfig: kDefaultIIREqualizerParamString,
    ParamID.iirEqualizerEffectEnabled: false,
    ParamID.virtualbassEffectEnabled: false,
    ParamID.virtualbassEffectEnvelopeRate: 40,
    ParamID.virtualbassEffectMidGain: 0.5,
    ParamID.virtualbassEffectHighGain: 0.5,
    ParamID.virtualbassEffectHarmonicGain: 1.30,
    ParamID.reverbEffectEnabled: false,
    ParamID.reverbEffectRoomSize: 0.54,
    ParamID.reverbEffectDamping: 0.25,
    ParamID.reverbEffectMix: 0.5,
    ParamID.reverbEffectStereoWidth: 1.0,
    ParamID.reverbEffectModDepth: 0.57,
    ParamID.reverbEffectModFreq: 4.3,
    ParamID.reverbEffectPreDelay: 20,
    ParamID.reverbEffectMatrixType: 0,
    ParamID.scriptEffectEnabled: false,
    ParamID.scriptEffectCode: kDefaultScriptCode,
    ParamID.scriptEffectParams: <ScriptParam>[],
    ParamID.diffSurroundingEffectEnabled: false,
    ParamID.diffSurroundingEffectDelayMs: 3,
    ParamID.viperReverbEffectEnabled: false,
    ParamID.viperReverbEffectRoomSize: 0.5,
    ParamID.viperReverbEffectWidth: 0.5,
    ParamID.viperReverbEffectDamp: 0.5,
    ParamID.viperReverbEffectWet: 0.3,
    ParamID.viperReverbEffectDry: 0.5,
    ParamID.viperReverbEffectMode: 0,
  };

  dynamic operator [](ParamID key) => _values[key];

  AudioConfig copyWith(Map<ParamID, dynamic> updates) {
    return AudioConfig({..._values, ...updates});
  }

  factory AudioConfig.fromJson(Map<String, dynamic> json) {
    final values = Map<ParamID, dynamic>.from(_defaultValues);

    for (final paramID in ParamID.values) {
      final jsonValue = json[paramID.name];

      if (jsonValue != null) {
        if (paramID.type == int) {
          values[paramID] = (jsonValue as num).toInt();
        } else if (paramID.type == double) {
          values[paramID] = (jsonValue as num).toDouble();
        } else if (paramID.type == bool) {
          values[paramID] = jsonValue as bool;
        } else if (paramID.type == String) {
          values[paramID] = jsonValue as String;
        } else if (paramID.type == List<ScriptParam>) {
          values[paramID] = List<ScriptParam>.from(
            jsonValue.map((json) => ScriptParam.fromJson(json)),
          );
        }
      }
    }

    return AudioConfig(values);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};

    for (final paramID in ParamID.values) {
      final value = _values[paramID];

      if (paramID.type == bool) {
        json[paramID.name] = value as bool;
      } else if (paramID.type == String) {
        json[paramID.name] = value as String;
      } else if (paramID.type == int) {
        json[paramID.name] = value as int;
      } else if (paramID.type == double) {
        json[paramID.name] = value as double;
      } else if (paramID.type == List<ScriptParam>) {
        json[paramID.name] = value.map((p) => p.toJson()).toList();
      } else {
        json[paramID.name] = null;
      }
    }

    return json;
  }

  String toJsonString() => jsonEncode(toJson());

  static AudioConfig fromJsonString(String jsonString) {
    return AudioConfig.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }
}
