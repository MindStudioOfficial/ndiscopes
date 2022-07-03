import 'package:flutter/material.dart';
import 'package:ndiscopes/widgets/player.dart';

class Frame with ChangeNotifier {
  bool _overlayEnabled = false;
  double _overlayOpacity = 1;
  OverlayMode _overlayMode = OverlayMode.splitVertical;
  double _splitPos = 0.5;
  bool _flipSplit = false;
  bool _gridEnabled = false;
  bool _falseColorEnabled = false;
  bool _texturesInitialized = false;

  bool get overlayEnabled => _overlayEnabled;
  double get overlayOpacity => _overlayOpacity;
  OverlayMode get overlayMode => _overlayMode;
  double get splitPos => _splitPos;
  bool get flipSplit => _flipSplit;
  bool get gridEnabled => _gridEnabled;
  bool get falseColorEnabled => _falseColorEnabled;
  bool get texturesInitialized => _texturesInitialized;

  void toggleOverlay({bool? enabled}) {
    _overlayEnabled = enabled ?? !_overlayEnabled;
    notifyListeners();
  }

  void updateOverlayOpcaity(double opacity) {
    _overlayOpacity = opacity;
    notifyListeners();
  }

  void updateOverlayMode(OverlayMode mode) {
    _overlayMode = mode;
    notifyListeners();
  }

  void updateSplitPos(double pos) {
    _splitPos = pos;
    notifyListeners();
  }

  void updateFlipSplit(bool flip) {
    _flipSplit = flip;
    notifyListeners();
  }

  void toogleGrid({bool? enabled}) {
    _gridEnabled = enabled ?? !_gridEnabled;
    notifyListeners();
  }

  void toggleFalseColor({bool? enabled}) {
    _falseColorEnabled = enabled ?? !_falseColorEnabled;
    notifyListeners();
  }

  void toggleTexturesInitialized({bool? initialized}) {
    _texturesInitialized = initialized ?? !_texturesInitialized;
    notifyListeners();
  }
}
