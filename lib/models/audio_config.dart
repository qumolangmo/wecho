/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

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
  speakerEffectEnabled(bool),
  speakerEffectHpGain(double),
  speakerEffectBpGain(double),
  speakerEffect2HarmonicCoeffs(double),
  speakerEffect4HarmonicCoeffs(double),
  speakerEffect6HarmonicCoeffs(double),
  lookAheadSoftLimitEffectEnabled(bool),
  lowcatEffectEnabled(bool),
  lowcatEffectCutoffFrequency(int),
  iirEqualizerEffectEnabled(bool),
  iirEqualizerEffectCoeffs(List<IIREqualizerCoeffs>);

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
    ParamID.evenHarmonicEffectBase: 1.0,
    ParamID.evenHarmonicEffectWarm: 1.0,
    ParamID.evenHarmonicEffectSugar: 1.0,
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
    ParamID.speakerEffectEnabled: false,
    ParamID.speakerEffectHpGain: 1.0,
    ParamID.speakerEffectBpGain: 1.0,
    ParamID.speakerEffect2HarmonicCoeffs: 0.1,
    ParamID.speakerEffect4HarmonicCoeffs: 0.7,
    ParamID.speakerEffect6HarmonicCoeffs: 0.2,
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
