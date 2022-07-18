import 'package:flutter/material.dart';

class AppStatus with ChangeNotifier {
  String _statusText = "";
  bool _loading = true;
  bool _shutdown = false;

  AppStatus({
    String? statusText,
    bool? loading,
    bool? shutdown,
  }) {
    _statusText = statusText ?? _statusText;
    _loading = loading ?? _loading;
    _shutdown = shutdown ?? _shutdown;
  }

  String get statusText => _statusText;
  bool get loading => _loading;
  bool get shutdown => _shutdown;

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
}
