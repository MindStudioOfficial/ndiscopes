import 'package:flutter/material.dart';
import 'package:ndiscopes/service/settings.dart';

class ScopeSettings with ChangeNotifier {
  ScopeSettings({
    double? vScopeScale,
    List<bool>? linesEnabled,
    List<bool>? scaleEnabled,
    List<WFScaleTypes>? scaleTypes,
    bool? audioLevelEnabled,
    bool? audioOutputEnabled,
    List<ScopeTypes>? scopeLayout,
  }) {
    _vScopeScale = vScopeScale ?? _vScopeScale;
    _audioLevelEnabled = audioLevelEnabled ?? _audioLevelEnabled;
    _audioOutputEnabled = audioOutputEnabled ?? _audioOutputEnabled;
    _scopeLayout = scopeLayout ?? _scopeLayout;
    _linesEnabled = linesEnabled ?? _linesEnabled;
    _scaleEnabled = scaleEnabled ?? _scaleEnabled;
    _scaleTypes = scaleTypes ?? _scaleTypes;
  }

  double _vScopeScale = 0.5;
  bool _audioLevelEnabled = true;
  bool _audioOutputEnabled = false;
  List<bool> _linesEnabled = List<bool>.generate(ScopeTypes.values.length, (index) => true);
  List<bool> _scaleEnabled = List<bool>.generate(ScopeTypes.values.length, (index) => true);
  List<WFScaleTypes> _scaleTypes =
      List<WFScaleTypes>.generate(ScopeTypes.values.length, (index) => WFScaleTypes.percentage);

  List<ScopeTypes> _scopeLayout = List.from(
    [ScopeTypes.luma, ScopeTypes.rgb, ScopeTypes.parade],
    growable: false,
  );

  double get vScopeScale => _vScopeScale;
  List<bool> get scaleEnabled => _scaleEnabled;
  List<bool> get linesEnabled => _linesEnabled;
  List<WFScaleTypes> get scaleTypes => _scaleTypes;
  bool get audioLevelEnabled => _audioLevelEnabled;
  bool get audioOutputEnabled => _audioOutputEnabled;
  List<ScopeTypes> get scopeLayout => _scopeLayout;

  Set<ScopeTypes> get scopeTypes => Set<ScopeTypes>.from(scopeLayout);

  void updateVScopeScale(double scale) {
    _vScopeScale = scale;
    notifyListeners();
  }

  void toggleShowScale(ScopeTypes scope, {bool? show}) {
    _scaleEnabled[scope.index] = show ?? !_scaleEnabled[scope.index];
    notifyListeners();
  }

  void toggleShowLines(ScopeTypes scope, {bool? show}) {
    _linesEnabled[scope.index] = show ?? !_linesEnabled[scope.index];
    notifyListeners();
  }

  void updateWVScaleType(ScopeTypes scope, WFScaleTypes scale) {
    _scaleTypes[scope.index] = scale;
    notifyListeners();
  }

  void toggleAudioLevel({bool? enable}) {
    _audioLevelEnabled = enable ?? !_audioLevelEnabled;
    notifyListeners();
  }

  void toggleAudioOutput({bool? enable}) {
    _audioOutputEnabled = enable ?? !_audioOutputEnabled;
    notifyListeners();
  }

  void updateScopeLayout(int index, ScopeTypes type) {
    if (index >= _scopeLayout.length || index < 0) return;
    _scopeLayout[index] = type;
    notifyListeners();
  }

  void update(ScopeSettings n) {
    _linesEnabled = n.linesEnabled;
    _scaleEnabled = n.scaleEnabled;
    _scaleTypes = n.scaleTypes;
    _vScopeScale = n.vScopeScale;
    _audioLevelEnabled = n.audioLevelEnabled;
    _audioOutputEnabled = n.audioOutputEnabled;
    _scopeLayout = n.scopeLayout;
    notifyListeners();
  }

  factory ScopeSettings.fromJson(Map<String, dynamic> json) {
    return ScopeSettings(
      linesEnabled: List<bool>.from(json["linesEnabled"]),
      scaleEnabled: List<bool>.from(json["scaleEnabled"]),
      scaleTypes: List<WFScaleTypes>.generate(
        ScopeTypes.values.length,
        (index) => WFScaleTypes.values[json["scaleTypes"]?[index] ?? 0],
      ),
      vScopeScale: json["vScopeScale"],
      audioLevelEnabled: json["audioLevelEnabled"],
      audioOutputEnabled: json["audioOutputEnabled"],
      scopeLayout: List<ScopeTypes>.generate(
        3,
        (index) => ScopeTypes.values[json["scopeLayout"]?[index] ?? index],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "vScopeScale": _vScopeScale,
      "audioLevelEnabled": _audioLevelEnabled,
      "audioOutputEnabled": _audioOutputEnabled,
      "scopeLayout": List<int>.generate(
        3,
        (index) => _scopeLayout[index].index,
      ),
      "linesEnabled": _linesEnabled,
      "scaleEnabled": _scaleEnabled,
      "scaleTypes": List<int>.generate(
        ScopeTypes.values.length,
        (index) => _scaleTypes[index].index,
      ),
    };
  }

  ScopeSettings copyWith() {
    return ScopeSettings();
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    saveSettings(this);
  }
}

enum WFScaleTypes {
  percentage,
  bits,
}

enum ScopeTypes {
  luma,
  rgb,
  parade,
  histogram,
  yuvparade,
  blacklevel,
}

Map<ScopeTypes, String> scopeTypeNames = {
  ScopeTypes.histogram: "Histogram",
  ScopeTypes.luma: "Luminance Waveform",
  ScopeTypes.parade: "RGB Parade",
  ScopeTypes.rgb: "RGB Waveform",
  ScopeTypes.yuvparade: "YUV Parade",
  ScopeTypes.blacklevel: "Black Level"
};

abstract class ScopeSize {
  static const int width = 580;
  static const int height = 256;
}
