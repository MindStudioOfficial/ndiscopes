import 'package:flutter/material.dart';

class Statistics with ChangeNotifier {
  double _renderFrameRate = 0;
  Duration _renderDelay = Duration.zero;
  int _sourceCount = 0;
  int _sourceIndex = -1;
  Size _frameSize = Size.zero;
  double _frameRate = 0;
  int _lastFrameTime = 0;

  Statistics({
    double? renderFrameRate,
    Duration? renderDelay,
    int? sourceCount,
    int? sourceIndex,
    Size? frameSize,
    double? frameRate,
  }) {
    _renderFrameRate = renderFrameRate ?? _renderFrameRate;
    _renderDelay = renderDelay ?? _renderDelay;
    _sourceCount = sourceCount ?? _sourceCount;
    _sourceIndex = sourceIndex ?? _sourceIndex;
    _frameSize = frameSize ?? _frameSize;
    _frameRate = frameRate ?? _frameRate;
  }

  double get renderFrameRate => _renderFrameRate;
  Duration get renderDelay => _renderDelay;
  int get sourceCount => _sourceCount;
  int get sourceIndex => _sourceIndex;
  Size get frameSize => _frameSize;
  double get frameRate => _frameRate;

  void calculateRenderFrameRate() {
    int now = DateTime.now().microsecondsSinceEpoch;
    _renderFrameRate = 1000000 / (now - _lastFrameTime);
    _lastFrameTime = now;
    notifyListeners();
  }

  void updateRenderFrameRate(double renderFrameRate) {
    _renderFrameRate = renderFrameRate;
    notifyListeners();
  }

  void updateRenderDelay(Duration renderDelay) {
    _renderDelay = renderDelay;
    notifyListeners();
  }

  void updateSourceCount(int count) {
    _sourceCount = count;
    notifyListeners();
  }

  void updateSourceIndex(int index) {
    _sourceIndex = index;
    notifyListeners();
  }

  void updateFrameSize(Size size) {
    _frameSize = size;
    notifyListeners();
  }

  void updateFrameRate(double frameRate) {
    _frameRate = frameRate;
    notifyListeners();
  }

  void update({
    double? renderFrameRate,
    Duration? renderDelay,
    int? sourceCount,
    int? sourceIndex,
    Size? frameSize,
    double? frameRate,
  }) {
    _renderFrameRate = renderFrameRate ?? _renderFrameRate;
    _renderDelay = renderDelay ?? _renderDelay;
    _sourceCount = sourceCount ?? _sourceCount;
    _sourceIndex = sourceIndex ?? _sourceIndex;
    _frameSize = frameSize ?? _frameSize;
    _frameRate = frameRate ?? _frameRate;
    notifyListeners();
  }
}
