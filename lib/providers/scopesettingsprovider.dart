import 'package:flutter/material.dart';
import 'package:ndiscopes/service/settings.dart';

class ScopeSettings with ChangeNotifier {
  ScopeSettings({
    double? vScopeScale,
    bool? showWFScale,
    WFScaleTypes? wfScaleType,
    bool? enableWFBackdrop,
    double? backdropOpacity,
  }) {
    _vScopeScale = vScopeScale ?? _vScopeScale;
    _showWFScale = showWFScale ?? _showWFScale;
    _wFScaleType = wfScaleType ?? _wFScaleType;
    _enableWFBackdrop = enableWFBackdrop ?? _enableWFBackdrop;
    _backdropOpacity = backdropOpacity ?? _backdropOpacity;
  }

  double _vScopeScale = 0.5;
  bool _showWFScale = true;
  WFScaleTypes _wFScaleType = WFScaleTypes.percentage;
  bool _enableWFBackdrop = false;
  double _backdropOpacity = 0.3;

  double get vScopeScale => _vScopeScale;
  bool get showWFScale => _showWFScale;
  WFScaleTypes get wFScaleType => _wFScaleType;
  bool get enableWFBackdrop => _enableWFBackdrop;
  double get backdropOpacity => _backdropOpacity;

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

  update(ScopeSettings n) {
    _backdropOpacity = n.backdropOpacity;
    _enableWFBackdrop = n.enableWFBackdrop;
    _showWFScale = n.showWFScale;
    _vScopeScale = n.vScopeScale;
    _wFScaleType = n.wFScaleType;
    notifyListeners();
  }

  factory ScopeSettings.fromJson(Map<String, dynamic> json) {
    return ScopeSettings(
      backdropOpacity: json["backdropOpacity"],
      enableWFBackdrop: json["enableWFBackdrop"],
      showWFScale: json["showWFScale"],
      vScopeScale: json["vScopeScale"],
      wfScaleType: WFScaleTypes.values.elementAt(json["wfScaleType"]),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "backdropOpacity": _backdropOpacity,
      "enableWFBackdrop": _enableWFBackdrop,
      "showWFScale": _showWFScale,
      "vScopeScale": _vScopeScale,
      "wfScaleType": _wFScaleType.index,
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
