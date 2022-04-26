import 'package:flutter/material.dart';

class AudioLevel with ChangeNotifier {
  List<double> _levels = [];

  List<double> get levels => _levels;

  void setLevels(List<double> levels) {
    _levels = levels;
    notifyListeners();
  }
}
