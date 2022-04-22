import 'package:flutter/material.dart';

class MaskProvider with ChangeNotifier {
  Rect _rect = Rect.zero;
  bool _active = false;

  Rect get rect => _rect;
  bool get active => _active;

  void updateRect(Rect rect) {
    _rect = rect;
    notifyListeners();
  }

  void toogle({bool? active}) {
    _active = active ?? !_active;
    notifyListeners();
  }
}
