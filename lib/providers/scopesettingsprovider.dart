import 'package:flutter/material.dart';
import 'package:ndiscopes/service/settings.dart';

class ScopeSettings with ChangeNotifier {
  ScopeSettings({
    double? vScopeScale,
    bool? showWFScale,
    WFScaleTypes? wfScaleType,
    bool? enableWFBackdrop,
    double? backdropOpacity,
    bool? audioLevelEnabled,
    bool? audioOutputEnabled,
    List<ScopeTypes>? scopeLayout,
  }) {
    _vScopeScale = vScopeScale ?? _vScopeScale;
    _showWFScale = showWFScale ?? _showWFScale;
    _wFScaleType = wfScaleType ?? _wFScaleType;
    _enableWFBackdrop = enableWFBackdrop ?? _enableWFBackdrop;
    _backdropOpacity = backdropOpacity ?? _backdropOpacity;
    _audioLevelEnabled = audioLevelEnabled ?? _audioLevelEnabled;
    _audioOutputEnabled = audioOutputEnabled ?? _audioOutputEnabled;
    _scopeLayout = scopeLayout ?? _scopeLayout;
  }

  double _vScopeScale = 0.5;
  bool _showWFScale = true;
  WFScaleTypes _wFScaleType = WFScaleTypes.percentage;
  bool _enableWFBackdrop = false;
  double _backdropOpacity = 0.3;
  bool _audioLevelEnabled = true;
  bool _audioOutputEnabled = false;
  List<ScopeTypes> _scopeLayout = List.from(
    [ScopeTypes.luma, ScopeTypes.rgb, ScopeTypes.parade],
    growable: false,
  );

  double get vScopeScale => _vScopeScale;
  bool get showWFScale => _showWFScale;
  WFScaleTypes get wFScaleType => _wFScaleType;
  bool get enableWFBackdrop => _enableWFBackdrop;
  double get backdropOpacity => _backdropOpacity;
  bool get audioLevelEnabled => _audioLevelEnabled;
  bool get audioOutputEnabled => _audioOutputEnabled;
  List<ScopeTypes> get scopeLayout => _scopeLayout;

  Set<ScopeTypes> get scopeTypes => Set<ScopeTypes>.from(scopeLayout);

  void updateVScopeScale(double scale) {
    _vScopeScale = scale;
    notifyListeners();
  }

  void toogleShowWVScale({bool? show}) {
    _showWFScale = show ?? !_showWFScale;
    notifyListeners();
  }

  void updateWVScaleType(WFScaleTypes type) {
    _wFScaleType = type;
    notifyListeners();
  }

  void toggleWVBackdrop({bool? enable}) {
    _enableWFBackdrop = enable ?? !_enableWFBackdrop;
    notifyListeners();
  }

  void updateBackdropOpacity(double opacity) {
    _backdropOpacity = opacity;
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
    _backdropOpacity = n.backdropOpacity;
    _enableWFBackdrop = n.enableWFBackdrop;
    _showWFScale = n.showWFScale;
    _vScopeScale = n.vScopeScale;
    _wFScaleType = n.wFScaleType;
    _audioLevelEnabled = n.audioLevelEnabled;
    _audioOutputEnabled = n.audioOutputEnabled;
    _scopeLayout = n.scopeLayout;
    notifyListeners();
  }

  factory ScopeSettings.fromJson(Map<String, dynamic> json) {
    return ScopeSettings(
      backdropOpacity: json["backdropOpacity"],
      enableWFBackdrop: json["enableWFBackdrop"],
      showWFScale: json["showWFScale"],
      vScopeScale: json["vScopeScale"],
      wfScaleType: WFScaleTypes.values.elementAt(json["wfScaleType"]),
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
      "backdropOpacity": _backdropOpacity,
      "enableWFBackdrop": _enableWFBackdrop,
      "showWFScale": _showWFScale,
      "vScopeScale": _vScopeScale,
      "wfScaleType": _wFScaleType.index,
      "audioLevelEnabled": _audioLevelEnabled,
      "audioOutputEnabled": _audioOutputEnabled,
      "scopeLayout": List<int>.generate(
        3,
        (index) => _scopeLayout[index].index,
      ),
    };
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
