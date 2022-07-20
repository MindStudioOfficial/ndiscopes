import 'package:flutter/material.dart';

class AppStatus with ChangeNotifier {
  String _statusText = "";
  bool _loading = true;
  bool _shutdown = false;

  bool _settingsOpen = false;
  bool _framesOpen = false;

  AppStatus({
    String? statusText,
    bool? loading,
    bool? shutdown,
    bool? settingsOpen,
    bool? framesOpen,
  }) {
    _statusText = statusText ?? _statusText;
    _loading = loading ?? _loading;
    _shutdown = shutdown ?? _shutdown;
    _settingsOpen = settingsOpen ?? _settingsOpen;
    _framesOpen = framesOpen ?? _framesOpen;
  }

  String get statusText => _statusText;
  bool get loading => _loading;
  bool get shutdown => _shutdown;
  bool get settingsOpen => _settingsOpen;
  bool get framesOpen => _framesOpen;

  void updateStatusText(String text) {
    _statusText = text;
    notifyListeners();
  }

  void toggleLoading({bool? loading}) {
    _loading = loading ?? !_loading;
    notifyListeners();
  }

  void toggleShutdown({bool? shutdown}) {
    _shutdown = shutdown ?? !_shutdown;
    notifyListeners();
  }

  void toggleSettings({bool? open}) {
    _settingsOpen = open ?? !_settingsOpen;
    notifyListeners();
  }

  void toggleFrames({bool? open}) {
    _framesOpen = open ?? !_framesOpen;
    notifyListeners();
  }
}
