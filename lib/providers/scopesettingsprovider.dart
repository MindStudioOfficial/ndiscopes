import 'package:flutter/material.dart';

class ScopeSettings with ChangeNotifier {
  double _vScopeScale = 0.5;
  bool _showWVScale = true;
  WFScaleTypes _wVScaleType = WFScaleTypes.percentage;
  bool _enableWVBackdrop = false;
  double _backdropOpacity = 0.3;

  double get vScopeScale => _vScopeScale;
  bool get showWVScale => _showWVScale;
  WFScaleTypes get wVScaleType => _wVScaleType;
  bool get enableWVBackdrop => _enableWVBackdrop;
  double get backdropOpacity => _backdropOpacity;

  void updateVScopeScale(double scale) {
    _vScopeScale = scale;
    notifyListeners();
  }

  void toogleShowWVScale({bool? show}) {
    _showWVScale = show ?? !_showWVScale;
    notifyListeners();
  }

  void updateWVScaleType(WFScaleTypes type) {
    _wVScaleType = type;
    notifyListeners();
  }

  void toggleWVBackdrop({bool? enable}) {
    _enableWVBackdrop = enable ?? !_enableWVBackdrop;
    notifyListeners();
  }

  void updateBackdropOpacity(double opacity) {
    _backdropOpacity = opacity;
    notifyListeners();
  }
}

enum WFScaleTypes {
  percentage,
  bits,
}
