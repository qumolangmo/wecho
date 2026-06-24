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

class IIREqualizerCoeffs {
  final int index;
  final int startFreq;
  final int endFreq;
  final int gain;

  IIREqualizerCoeffs(this.index, this.startFreq, this.endFreq, this.gain);

  void _packInto(ByteData data, int offset) {
    data.setInt32(offset, index, Endian.host);
    data.setInt32(offset + 4, startFreq, Endian.host);
    data.setInt32(offset + 8, endFreq, Endian.host);
    data.setInt32(offset + 12, gain, Endian.host);
  }

  static const int sizeInBytes = 16;
}

/* now IIR Equalizer Effect only support 10 bands, so coeffs length must be 10*/
Uint8List serializeIIREqualizerCoeffs(List<IIREqualizerCoeffs> coeffs) {
  final int length = coeffs.length;
  if (length != 10) {
    throw ArgumentError('coeffs length must be 10');
  }
  final ByteData data = ByteData(length * IIREqualizerCoeffs.sizeInBytes);
  for (int i = 0; i < length; i++) {
    coeffs[i]._packInto(data, i * IIREqualizerCoeffs.sizeInBytes);
  }
  return data.buffer.asUint8List();
}

Uint8List serializeScriptParams(List<ScriptParam> params) {
  final int length = params.length;
  if (length != 16) {
    throw ArgumentError('params length must be 16');
  }
  final ByteData data = ByteData(length * 68); // name[64] + value(4)
  for (int i = 0; i < length; i++) {
    final nameBytes = params[i].name.codeUnits;
    final nameLen = nameBytes.length < 64 ? nameBytes.length : 63;
    for (int j = 0; j < nameLen; j++) {
      data.setUint8(i * 68 + j, nameBytes[j]);
    }
    data.setFloat32(i * 68 + 64, params[i].value, Endian.host);
  }
  return data.buffer.asUint8List();
}

class ScriptParam {
  final String name;
  final double value;

  ScriptParam(this.name, this.value);

  Map<String, dynamic> toJson() => {'name': name, 'value': value};

  factory ScriptParam.fromJson(Map<String, dynamic> json) =>
      ScriptParam(json['name'] as String, (json['value'] as num).toDouble());
}

enum ParamID {
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
  limiterEffectEnabled(bool),
  limiterEffectThreshold(int),
  limiterEffectRatio(int),
  limiterEffectMakeupGain(int),
  limiterEffectAttack(int),
  limiterEffectRelease(int),
  lookAheadSoftLimitEffectEnabled(bool),
  lowcatEffectEnabled(bool),
  lowcatEffectCutoffFrequency(int),
  iirEqualizerEffectEnabled(bool),
  iirEqualizerEffectCoeffs(List<IIREqualizerCoeffs>),
  virtualbassEffectEnabled(bool),
  virtualbassEffectEnvelopeRate(int),
  reverbEffectEnabled(bool),
  reverbEffectRoomSize(double),
  reverbEffectDamping(double),
  reverbEffectWetMix(double),
  reverbEffectPreDelay(int),
  scriptEffectEnabled(bool),
  scriptEffectCode(String),
  scriptEffectParams(List<ScriptParam>);

  final Type type;

  const ParamID(this.type);
}

class AudioConfig {
  final Map<ParamID, dynamic> _values;

  AudioConfig([Map<ParamID, dynamic>? values])
      : _values = values ?? _defaultValues;

  static final Map<ParamID, dynamic> _defaultValues = {
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
    ParamID.limiterEffectEnabled: false,
    ParamID.limiterEffectThreshold: 0,
    ParamID.limiterEffectRatio: 1,
    ParamID.limiterEffectMakeupGain: 1,
    ParamID.limiterEffectAttack: 2,
    ParamID.limiterEffectRelease: 2,
    ParamID.lookAheadSoftLimitEffectEnabled: false,
    ParamID.lowcatEffectEnabled: false,
    ParamID.lowcatEffectCutoffFrequency: 120,
    ParamID.iirEqualizerEffectCoeffs: <IIREqualizerCoeffs>[
      IIREqualizerCoeffs(0, 20, 63, 0),
      IIREqualizerCoeffs(1, 63, 125, 0),
      IIREqualizerCoeffs(2, 125, 250, 0),
      IIREqualizerCoeffs(3, 250, 500, 0),
      IIREqualizerCoeffs(4, 500, 1000, 0),
      IIREqualizerCoeffs(5, 1000, 2000, 0),
      IIREqualizerCoeffs(6, 2000, 4000, 0),
      IIREqualizerCoeffs(7, 4000, 8000, 0),
      IIREqualizerCoeffs(8, 8000, 16000, 0),
      IIREqualizerCoeffs(9, 16000, 20000, 0),
    ],
    ParamID.iirEqualizerEffectEnabled: false,
    ParamID.virtualbassEffectEnabled: false,
    ParamID.virtualbassEffectEnvelopeRate: 50,
    ParamID.reverbEffectEnabled: false,
    ParamID.reverbEffectRoomSize: 0.5,
    ParamID.reverbEffectDamping: 0.5,
    ParamID.reverbEffectWetMix: 0.3,
    ParamID.reverbEffectPreDelay: 20,
    ParamID.scriptEffectEnabled: false,
    ParamID.scriptEffectCode: '''
#define SAMPLE_RATE 48000
#define SAMPLES_PER_CHANNEL 512

/*
  Biquad_ get_biquad(int index);
  void biquad_reset(Biquad_ ctx);
  void biquad_set_hp(Biquad_ ctx, float cutoff, float q);
  void biquad_set_lp(Biquad_ ctx, float cutoff, float q);
  void biquad_set_peak(Biquad_ ctx, float cutoff, float q, float gain);
  void biquad_process_block(Biquad_ ctx, float* input, float* output);

  Convolver_ get_convolver(int index);
  void convolver_reset(Convolver_ ctx);
  void convolver_set_ir(Convolver_ ctx, float* ir_l, float* ir_r, int samples);
  void convolver_set_ir_path(Convolver_ ctx, const char* path);
  void convolver_process_block(Convolver_ ctx, float* input_l, float* input_r, float* output_l, float* output_r);

  Harmonic_ get_harmonic(int index);
  void harmonic_reset(Harmonic_ ctx);
  void harmonic_set_coeffs(Harmonic_ ctx, float base, float order2, float order3, float order4, float order5, float order6, float order7, float order8);
  float harmonic_process(Harmonic_ ctx, float input);
  void harmonic_process_block(Harmonic_ ctx, float* input, float* output);
*/

void setParams(ScriptParams* params) {
    // params[0..15].name, params[0..15].value
}

float ll = 0, rr = 0;
float gain = 1.3;
/* this is a simple clarity enhancement algorithm. */
void run(float* in_l, float* in_r, float* out_l, float* out_r) {
    for (int i = 0; i < SAMPLES_PER_CHANNEL; i++) {
        float l = in_l[i];
        float r = in_r[i];
        float dl = l - ll;
        float dr = r - rr;
        ll = l;
        rr = r;
        out_l[i] = l + dl * gain;
        out_r[i] = r + dr * gain;
    }
}''',
    ParamID.scriptEffectParams: <ScriptParam>[
      ScriptParam('', 0),
      ScriptParam('', 0),
      ScriptParam('', 0),
      ScriptParam('', 0),
      ScriptParam('', 0),
      ScriptParam('', 0),
      ScriptParam('', 0),
      ScriptParam('', 0),
      ScriptParam('', 0),
      ScriptParam('', 0),
      ScriptParam('', 0),
      ScriptParam('', 0),
      ScriptParam('', 0),
      ScriptParam('', 0),
      ScriptParam('', 0),
      ScriptParam('', 0),
    ],
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
        } else if (paramID.type == List<IIREqualizerCoeffs>) {
          values[paramID] = List<IIREqualizerCoeffs>.from(
            jsonValue.map((json) => IIREqualizerCoeffs(
              json['index'],
              json['startFreq'],
              json['endFreq'],
              json['gain'],
            )),
          );
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
      } else if (paramID.type == List<IIREqualizerCoeffs>) {
        json[paramID.name] = value.map((coeffs) => {
          'index': coeffs.index,
          'startFreq': coeffs.startFreq,
          'endFreq': coeffs.endFreq,
          'gain': coeffs.gain,
        }).toList();
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
