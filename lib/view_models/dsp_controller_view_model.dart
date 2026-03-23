/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ParamID {
  GAIN_EFFECT_GAIN,
  BALANCE_EFFECT_BALANCE,
  BASS_EFFECT_ENABLED,
  BASS_EFFECT_GAIN,
  BASS_EFFECT_CENTER_FREQ,
  BASS_EFFECT_Q,
  CLARITY_EFFECT_ENABLED,
  CLARITY_EFFECT_GAIN,
  EVEN_HARMONIC_EFFECT_ENABLED,
  EVEN_HARMONIC_EFFECT_GAIN,
  CONVOLVE_EFFECT_ENABLED,
  CONVOLVE_EFFECT_MIX,
  CONVOLVE_EFFECT_IR_PATH,
  LIMITER_EFFECT_ENABLED,
  LIMITER_EFFECT_THRESHOLD,
  LIMITER_EFFECT_RATIO,
  LIMITER_EFFECT_MAKEUP_GAIN,
  LIMITER_EFFECT_ATTACK,
  LIMITER_EFFECT_RELEASE,
  SPEAKER_EFFECT_ENABLED,
  SPEAKER_EFFECT_HP_GAIN,
  SPEAKER_EFFECT_BP_GAIN,
  SPEAKER_EFFECT_2_HARMONIC_COEFFS,
  SPEAKER_EFFECT_4_HARMONIC_COEFFS,
  SPEAKER_EFFECT_6_HARMONIC_COEFFS,
  LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED,
}

class DSPControllerViewModel {
  double channelBalance = 0;

  double globalGain = 0;

  bool limiterEnabled = false;
  double limiterThreshold = 0;
  double limiterRatio = 0;
  double limiterMakeupGain = 0;
  double limiterAttack = 0;
  double limiterRelease = 0;

  double clarity = 0;
  bool clarityEnabled = false;

  double bassBoost = 0;
  bool bassBoostEnabled = false;
  double bassCenterFreq = 60;
  double bassQ = 0.6;

  bool evenHarmonicEnabled = false;
  double evenHarmonicGain = 0;

  bool convolveEnabled = false;
  double convolveMix = 0.5;
  String convolveIrPath = '';

  bool speakerExciterEnabled = false;
  double speakerExciterHpGain = 1;
  double speakerExciterBpGain = 1;
  double speakerExciter2HarmonicCoeffs = 0.1;
  double speakerExciter4HarmonicCoeffs = 0.7;
  double speakerExciter6HarmonicCoeffs = 0.2;

  bool multibandLimiterEnabled = false;


  bool channelBalanceExpanded = false;
  bool globalGainExpanded = false;
  bool clarityExpanded = false;
  bool bassBoostExpanded = false;
  bool evenHarmonicExpanded = false;
  bool convolveExpanded = false;
  bool limiterExpanded = false;
  bool speakerExciterExpanded = false;

  bool isCapturing = false;
  bool masterEnabled = true;
  late MethodChannel _channel;
  late SharedPreferences _prefs;
  Function()? onStateChanged;

  DSPControllerViewModel({this.onStateChanged}) {
    _initialize();
  }

  Future<void> _initialize() async {
    _channel = const MethodChannel('audio_capture');
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'updateCaptureStatus') {
        isCapturing = call.arguments as bool;
        onStateChanged?.call();
      }
      return null;
    });
    await _loadSettings();

    updateMasterEnabled(masterEnabled);
  
    updateLimiterThreshold(limiterThreshold);
    updateLimiterRatio(limiterRatio);
    updateLimiterMakeupGain(limiterMakeupGain);
    updateLimiterAttack(limiterAttack);
    updateLimiterRelease(limiterRelease);
    updateLimiterEnabled(limiterEnabled);


    updateChannelBalance(channelBalance);
    updateGlobalGain(globalGain);

    
    updateBassBoost(bassBoost);
    updateBassCenterFreq(bassCenterFreq);
    updateBassQ(bassQ);
    updateBassBoostEnabled(bassBoostEnabled);
    
    
    updateClarity(clarity);
    updateClarityEnabled(clarityEnabled);

    
    updateEvenHarmonicGain(evenHarmonicGain);
    updateEvenHarmonicEnabled(evenHarmonicEnabled);

    
    updateConvolveMix(convolveMix);
    updateConvolveIrPath(convolveIrPath);
    updateConvolveEnabled(convolveEnabled);
  

    updateSpeakerExciterHpGain(speakerExciterHpGain);
    updateSpeakerExciterBpGain(speakerExciterBpGain);
    updateSpeakerExciter2HarmonicCoeffs(speakerExciter2HarmonicCoeffs);
    updateSpeakerExciter4HarmonicCoeffs(speakerExciter4HarmonicCoeffs);
    updateSpeakerExciter6HarmonicCoeffs(speakerExciter6HarmonicCoeffs);
    updateSpeakerExciterEnabled(speakerExciterEnabled);

    updateMultibandLimiterEnabled(multibandLimiterEnabled);
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    channelBalance = _prefs.getDouble('channelBalance') ?? 0;
    globalGain = _prefs.getDouble('globalGain') ?? 0;
    clarity = _prefs.getDouble('clarity') ?? 0;
    clarityEnabled = _prefs.getBool('clarityEnabled') ?? false;
    bassBoost = _prefs.getDouble('bassBoost') ?? 0;
    bassBoostEnabled = _prefs.getBool('bassBoostEnabled') ?? false;
    bassCenterFreq = _prefs.getDouble('bassCenterFreq') ?? 60;
    bassQ = _prefs.getDouble('bassQ') ?? 0.6;
    masterEnabled = _prefs.getBool('masterEnabled') ?? true;
    evenHarmonicEnabled = _prefs.getBool('evenHarmonicEnabled') ?? false;
    evenHarmonicGain = _prefs.getDouble('evenHarmonicGain') ?? 0;
    convolveEnabled = _prefs.getBool('convolveEnabled') ?? false;
    convolveMix = _prefs.getDouble('convolveMix') ?? 0.5;
    convolveIrPath = _prefs.getString('convolveIrPath') ?? '';

    limiterThreshold = _prefs.getDouble('limiterThreshold') ?? 0;
    limiterRatio = _prefs.getDouble('limiterRatio') ?? 1;
    limiterMakeupGain = _prefs.getDouble('limiterMakeupGain') ?? 1;
    limiterAttack = _prefs.getDouble('limiterAttack') ?? 2;
    limiterRelease = _prefs.getDouble('limiterRelease') ?? 2;
    limiterEnabled = _prefs.getBool('limiterEnabled') ?? false;

    speakerExciterHpGain = _prefs.getDouble('speakerExciterHpGain') ?? 1.0;
    speakerExciterBpGain = _prefs.getDouble('speakerExciterBpGain') ?? 1.0;
    speakerExciter2HarmonicCoeffs = _prefs.getDouble('speakerExciter2HarmonicCoeffs') ?? 0.1;
    speakerExciter4HarmonicCoeffs = _prefs.getDouble('speakerExciter4HarmonicCoeffs') ?? 0.7;
    speakerExciter6HarmonicCoeffs = _prefs.getDouble('speakerExciter6HarmonicCoeffs') ?? 0.2;
    speakerExciterEnabled = _prefs.getBool('speakerExciterEnabled') ?? false;

    multibandLimiterEnabled = _prefs.getBool('multibandLimiterEnabled') ?? false;

    channelBalanceExpanded = _prefs.getBool('channelBalanceExpanded') ?? false;
    globalGainExpanded = _prefs.getBool('globalGainExpanded') ?? false;
    clarityExpanded = _prefs.getBool('clarityExpanded') ?? false;
    bassBoostExpanded = _prefs.getBool('bassBoostExpanded') ?? false;
    evenHarmonicExpanded = _prefs.getBool('evenHarmonicExpanded') ?? false;
    convolveExpanded = _prefs.getBool('convolveExpanded') ?? false;
    limiterExpanded = _prefs.getBool('limiterExpanded') ?? false;
    speakerExciterExpanded = _prefs.getBool('speakerExciterExpanded') ?? false;

    onStateChanged?.call();
  }

  Future<void> _saveSettings() async {
    await _prefs.setDouble('channelBalance', channelBalance);
    await _prefs.setDouble('globalGain', globalGain);
    await _prefs.setDouble('clarity', clarity);
    await _prefs.setBool('clarityEnabled', clarityEnabled);
    await _prefs.setDouble('bassBoost', bassBoost);
    await _prefs.setBool('bassBoostEnabled', bassBoostEnabled);
    await _prefs.setDouble('bassCenterFreq', bassCenterFreq);
    await _prefs.setDouble('bassQ', bassQ);
    await _prefs.setBool('evenHarmonicEnabled', evenHarmonicEnabled);
    await _prefs.setDouble('evenHarmonicGain', evenHarmonicGain);
    await _prefs.setBool('convolveEnabled', convolveEnabled);
    await _prefs.setDouble('convolveMix', convolveMix);
    await _prefs.setString('convolveIrPath', convolveIrPath);

    await _prefs.setBool('limiterEnabled', limiterEnabled);
    await _prefs.setDouble('limiterThreshold', limiterThreshold);
    await _prefs.setDouble('limiterRatio', limiterRatio);
    await _prefs.setDouble('limiterMakeupGain', limiterMakeupGain);
    await _prefs.setDouble('limiterAttack', limiterAttack);
    await _prefs.setDouble('limiterRelease', limiterRelease);

    await _prefs.setBool('speakerExciterEnabled', speakerExciterEnabled);
    await _prefs.setDouble('speakerExciterHpGain', speakerExciterHpGain);
    await _prefs.setDouble('speakerExciterBpGain', speakerExciterBpGain);
    await _prefs.setDouble('speakerExciter2HarmonicCoeffs', speakerExciter2HarmonicCoeffs);
    await _prefs.setDouble('speakerExciter4HarmonicCoeffs', speakerExciter4HarmonicCoeffs);
    await _prefs.setDouble('speakerExciter6HarmonicCoeffs', speakerExciter6HarmonicCoeffs);

    await _prefs.setBool('multibandLimiterEnabled', multibandLimiterEnabled);

    await _prefs.setBool('masterEnabled', masterEnabled);
    await _prefs.setBool('channelBalanceExpanded', channelBalanceExpanded);
    await _prefs.setBool('globalGainExpanded', globalGainExpanded);
    await _prefs.setBool('clarityExpanded', clarityExpanded);
    await _prefs.setBool('bassBoostExpanded', bassBoostExpanded);
    await _prefs.setBool('evenHarmonicExpanded', evenHarmonicExpanded);
    await _prefs.setBool('convolveExpanded', convolveExpanded);
    await _prefs.setBool('limiterExpanded', limiterExpanded);
    await _prefs.setBool('speakerExciterExpanded', speakerExciterExpanded);
  }

  Future<void> toggleCapture() async {
    try {
      if (!isCapturing) {
        await _channel.invokeMethod('startCapture');
      } else {
        await _channel.invokeMethod('stopCapture');
      }
    } on PlatformException catch (e) {
      print('Error: ${e.message}');
    }
  }

  Future<void> setEffectParam(int paramId, dynamic value) async {
    try {
      await _channel.invokeMethod('setEffectParam', {
        'paramId': paramId,
        'value': value
      });
    } on PlatformException catch (e) {
      print('Error setting effect param: ${e.message}');
    }
  }

  Future<void> setMasterEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setMasterEnabled', enabled);
    } on PlatformException catch (e) {
      print('Error setting master enabled: ${e.message}');
    }
  }

  void updateChannelBalance(double value) {
    channelBalance = value;
    setEffectParam(ParamID.BALANCE_EFFECT_BALANCE.index, value.toInt());
    _saveSettings();
    onStateChanged?.call();
  }

  void updateGlobalGain(double value) {
    globalGain = value;
    setEffectParam(ParamID.GAIN_EFFECT_GAIN.index, value.toInt());
    _saveSettings();
    onStateChanged?.call();
  }

  void updateLimiterEnabled(bool enabled) {
    limiterEnabled = enabled;
    setEffectParam(ParamID.LIMITER_EFFECT_ENABLED.index, enabled);
    _saveSettings();
    onStateChanged?.call();
  }

  void updateLimiterThreshold(double value) {
    limiterThreshold = value;
    setEffectParam(ParamID.LIMITER_EFFECT_THRESHOLD.index, value.toInt());
    _saveSettings();
    onStateChanged?.call();
  }

  void updateLimiterRatio(double value) {
    limiterRatio = value;
    setEffectParam(ParamID.LIMITER_EFFECT_RATIO.index, value.toInt());
    _saveSettings();
    onStateChanged?.call();
  }

  void updateLimiterMakeupGain(double value) {
    limiterMakeupGain = value;
    setEffectParam(ParamID.LIMITER_EFFECT_MAKEUP_GAIN.index, value.toInt());
    _saveSettings();
    onStateChanged?.call();
  }

  void updateLimiterAttack(double value) {
    limiterAttack = value;
    setEffectParam(ParamID.LIMITER_EFFECT_ATTACK.index, value.toInt());
    _saveSettings();
    onStateChanged?.call();
  }

  void updateLimiterRelease(double value) {
    limiterRelease = value;
    setEffectParam(ParamID.LIMITER_EFFECT_RELEASE.index, value.toInt());
    _saveSettings();
    onStateChanged?.call();
  }



  void updateClarity(double value) {
    clarity = value;
    setEffectParam(ParamID.CLARITY_EFFECT_GAIN.index, value.toInt());
    _saveSettings();
    onStateChanged?.call();
  }

  void updateClarityEnabled(bool enabled) {
    clarityEnabled = enabled;
    setEffectParam(ParamID.CLARITY_EFFECT_ENABLED.index, enabled);
    _saveSettings();
    onStateChanged?.call();
  }

  void updateBassBoost(double value) {
    bassBoost = value;
    setEffectParam(ParamID.BASS_EFFECT_GAIN.index, value.toInt());
    _saveSettings();
    onStateChanged?.call();
  }

  void updateBassBoostEnabled(bool enabled) {
    bassBoostEnabled = enabled;
    setEffectParam(ParamID.BASS_EFFECT_ENABLED.index, enabled);
    _saveSettings();
    onStateChanged?.call();
  }

  void updateBassCenterFreq(double value) {
    bassCenterFreq = value;
    setEffectParam(ParamID.BASS_EFFECT_CENTER_FREQ.index, value.toInt());
    _saveSettings();
    onStateChanged?.call();
  }

  void updateBassQ(double value) {
    bassQ = value;
    setEffectParam(ParamID.BASS_EFFECT_Q.index, value);
    _saveSettings();
    onStateChanged?.call();
  }

  void updateEvenHarmonicEnabled(bool enabled) {
    evenHarmonicEnabled = enabled;
    setEffectParam(ParamID.EVEN_HARMONIC_EFFECT_ENABLED.index, enabled);
    _saveSettings();
    onStateChanged?.call();
  }

  void updateEvenHarmonicGain(double value) {
    evenHarmonicGain = value;
    setEffectParam(ParamID.EVEN_HARMONIC_EFFECT_GAIN.index, value.toInt());
    _saveSettings();
    onStateChanged?.call();
  }

  void updateSpeakerExciterEnabled(bool enabled) {
    speakerExciterEnabled = enabled;
    setEffectParam(ParamID.SPEAKER_EFFECT_ENABLED.index, enabled);
    _saveSettings();
    onStateChanged?.call();
  }

  void updateSpeakerExciter2HarmonicCoeffs(double value) {
    speakerExciter2HarmonicCoeffs = value;
    setEffectParam(ParamID.SPEAKER_EFFECT_2_HARMONIC_COEFFS.index, value);
    _saveSettings();
    onStateChanged?.call();
  }

  void updateSpeakerExciter4HarmonicCoeffs(double value) {
    speakerExciter4HarmonicCoeffs = value;
    setEffectParam(ParamID.SPEAKER_EFFECT_4_HARMONIC_COEFFS.index, value);
    _saveSettings();
    onStateChanged?.call();
  }

  void updateSpeakerExciter6HarmonicCoeffs(double value) {
    speakerExciter6HarmonicCoeffs = value;
    setEffectParam(ParamID.SPEAKER_EFFECT_6_HARMONIC_COEFFS.index, value);
    _saveSettings();
    onStateChanged?.call();
  }

  void updateSpeakerExciterHpGain(double value) {
    speakerExciterHpGain = value;
    setEffectParam(ParamID.SPEAKER_EFFECT_HP_GAIN.index, value);
    _saveSettings();
    onStateChanged?.call();
  }

  void updateSpeakerExciterBpGain(double value) {
    speakerExciterBpGain = value;
    setEffectParam(ParamID.SPEAKER_EFFECT_BP_GAIN.index, value);
    _saveSettings();
    onStateChanged?.call();
  }

  void updateMasterEnabled(bool enabled) {
    masterEnabled = enabled;
    setMasterEnabled(enabled);
    _saveSettings();
    onStateChanged?.call();
  }

  void toggleChannelBalanceExpanded() {
    channelBalanceExpanded = !channelBalanceExpanded;
    _saveSettings();
    onStateChanged?.call();
  }

  void toggleGlobalGainExpanded() {
    globalGainExpanded = !globalGainExpanded;
    _saveSettings();
    onStateChanged?.call();
  }

  void toggleClarityExpanded() {
    clarityExpanded = !clarityExpanded;
    _saveSettings();
    onStateChanged?.call();
  }

  void toggleBassBoostExpanded() {
    bassBoostExpanded = !bassBoostExpanded;
    _saveSettings();
    onStateChanged?.call();
  }

  void toggleEvenHarmonicExpanded() {
    evenHarmonicExpanded = !evenHarmonicExpanded;
    _saveSettings();
    onStateChanged?.call();
  }

  void toggleLimiterExpanded() {
    limiterExpanded = !limiterExpanded;
    _saveSettings();
    onStateChanged?.call();
  }

  void toggleSpeakerExciterExpanded() {
    speakerExciterExpanded = !speakerExciterExpanded;
    _saveSettings();
    onStateChanged?.call();
  }

  void updateConvolveEnabled(bool enabled) {
    convolveEnabled = enabled;
    setEffectParam(ParamID.CONVOLVE_EFFECT_ENABLED.index, enabled);
    _saveSettings();
    onStateChanged?.call();
  }

  void updateConvolveMix(double value) {
    convolveMix = value;
    setEffectParam(ParamID.CONVOLVE_EFFECT_MIX.index, value);
    _saveSettings();
    onStateChanged?.call();
  }

  void updateConvolveIrPath(String path) {
    convolveIrPath = path;
    setEffectParam(ParamID.CONVOLVE_EFFECT_IR_PATH.index, path);
    _saveSettings();
    onStateChanged?.call();
  }

  void toggleConvolveExpanded() {
    convolveExpanded = !convolveExpanded;
    _saveSettings();
    onStateChanged?.call();
  }

  void updateMultibandLimiterEnabled(bool enabled) {
    multibandLimiterEnabled = enabled;
    setEffectParam(ParamID.LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED.index, enabled);
    _saveSettings();
    onStateChanged?.call();
  }
}
