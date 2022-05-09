import 'dart:typed_data';
import 'package:libao/libao.dart';

class AudioPlayer {
  late Libao _ao;
  late int _driverId;
  Device? _device;
  int _bits = 16;
  int _channels = 2;
  int _sampleRate = 48000;

  AudioPlayer() {
    _ao = Libao.open("bin/libao.dll");
    _ao.initialize();
    _driverId = _ao.defaultDriverId();
    print(_ao.driverInfoList());
  }

  openDriver() {
    _device = _ao.openLive(_driverId,
        bits: _bits, channels: _channels, matrix: AudioChannelMapping.fivepointone, rate: _sampleRate);
  }

  play(Uint8List bytes) {
    if (_device == null) return;
    _ao.play(_device!, bytes);
  }

  updateDriver(int channels, int sampleRate, int bits) {
    if (channels == _channels && sampleRate == _sampleRate && bits == _bits) return;
    if (_device != null) _ao.close(_device!);
    _channels = channels;
    _sampleRate = sampleRate;
    _bits = bits;
    openDriver();
  }

  dispose() {
    if (_device != null) _ao.close(_device!);
    _ao.shutdown();
  }
}

class AudioChannelMapping {
  AudioChannelMapping._();
  static const String stereo = 'L,R';
  static const String quadraphonic = 'L,R,BL,BR';
  static const String fivepointone = 'L,R,C,LFE,BR,BL';
  static const String sevenpointone = 'L,R,C,LFE,BR,BL,SL,SR';
}
