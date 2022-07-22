import 'dart:ffi';
import 'dart:typed_data';
import 'package:libao/libao.dart';
import 'package:ffi/ffi.dart';

class AudioPlayer {
  late Libao _ao;
  late int _driverId;
  Device? _device;
  int _bits = 16;
  int _channels = 2;
  int _sampleRate = 48000;
  int _devID = 0;
  String _devName = "";

  AudioPlayer() {
    _ao = Libao.open("bin/libao.dll");
    _ao.initialize();
    _driverId = _ao.defaultDriverId();
  }

  openDriver(int index) {
    Pointer<AoOption> options = calloc<AoOption>();

    options.ref.key = "id".toNativeUtf8();
    options.ref.value = index.toString().toNativeUtf8();

    _devID = index;

    _device = _ao.openLive(
      _driverId,
      bits: _bits,
      channels: _channels,
      matrix: AudioChannelMapping.fivepointone,
      rate: _sampleRate,
      options: options,
    );
    _ao.freeOptions(options);
  }

  openDriverByName(String name) {
    Pointer<AoOption> options = calloc<AoOption>();

    options.ref.key = "dev".toNativeUtf8();
    // libao cuts off the name after the 31. character.
    // If name is longer libao won't find a match
    String dev = name.isNotEmpty ? name.substring(0, name.length >= 32 ? 31 : name.length) : "default";

    options.ref.value = dev.toNativeUtf8();
    _devName = name;
    _device = _ao.openLive(
      _driverId,
      bits: _bits,
      channels: _channels,
      matrix: AudioChannelMapping.fivepointone,
      rate: _sampleRate,
      options: options,
    );
    _ao.freeOptions(options);
  }

  play(Uint8List bytes) {
    if (_device == null) return;
    _ao.play(_device!, bytes);
  }

  updateDriver(int channels, int sampleRate, int bits, int devID) {
    if (channels == _channels && sampleRate == _sampleRate && bits == _bits && devID == _devID) return;
    if (_device != null) _ao.close(_device!);
    _channels = channels;
    _sampleRate = sampleRate;
    _bits = bits;
    _devID = devID;
    openDriver(devID);
  }

  updateDriverWithName(int channels, int sampleRate, int bits, String name) {
    if (channels == _channels && sampleRate == _sampleRate && bits == _bits && name == _devName) return;
    if (_device != null) _ao.close(_device!);
    _channels = channels;
    _sampleRate = sampleRate;
    _bits = bits;
    _devName = name;
    openDriverByName(name);
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
