import 'package:flutter/material.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'package:ndiscopes/widgets/player.dart';

class Frame with ChangeNotifier {
  NDIOutputFrame? _imageFrame;
  NDIOutputFrame? _overlayFrame;
  double _overlayOpacity = 1;
  OverlayMode _overlayMode = OverlayMode.splitVertical;
  double _splitPos = 0.5;
  bool _flipSplit = false;

  NDIOutputFrame? get imageFrame => _imageFrame;
  NDIOutputFrame? get overlayFrame => _overlayFrame;
  double get overlayOpacity => _overlayOpacity;
  OverlayMode get overlayMode => _overlayMode;
  double get splitPos => _splitPos;
  bool get flipSplit => _flipSplit;

  void updateImageFrame(NDIOutputFrame? frame) {
    _imageFrame = frame;
    notifyListeners();
  }

  void updateOverlayFrame(NDIOutputFrame? frame) {
    _overlayFrame = frame;
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
}
