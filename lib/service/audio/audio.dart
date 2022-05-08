import 'dart:typed_data';

import 'package:libao/libao.dart';

class AudioPlayer {
  late Libao _ao;
  late int _driverId;
  Device? _device;

  AudioPlayer() {
    _ao = Libao.open("bin/libao.dll");
    _ao.initialize();
    _driverId = _ao.defaultDriverId();
    print(_ao.driverInfoList());
  }

  openDriver() {
    _device = _ao.openLive(_driverId, bits: 16, channels: 2, matrix: 'L,R', rate: 48000);
  }

  play(Uint8List bytes) {
    if (_device == null) return;
    _ao.play(_device!, bytes);
  }
}
