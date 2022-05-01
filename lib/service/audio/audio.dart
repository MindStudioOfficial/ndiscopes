// ignore_for_file: non_constant_identifier_names

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:ndiscopes/bindings/portaudio_bindings.dart';

PortAudioFFI _pa = PortAudioFFI(DynamicLibrary.open("bin/libportaudio64bit.dll"));

class AudioPlayer {
  AudioPlayer() {
    if (_pa.Pa_Initialize() != PaErrorCode.paNoError) throw Exception("Could not initialize Audio");

    if (kDebugMode) {
      print(getVersion());
    }
  }

  String getVersion() {
    Pointer<Utf8> sp = _pa.Pa_GetVersionText().cast<Utf8>();
    String s = sp.toDartString();
    return s;
  }

  void getDevices() {
    int deviceCount = _pa.Pa_GetDeviceCount();
    for (int i = 0; i < deviceCount; i++) {
      Pointer<PaDeviceInfo> dev = _pa.Pa_GetDeviceInfo(i);
      print([
        dev.ref.name.cast<Utf8>().toDartString(),
        dev.ref.defaultSampleRate,
        dev.ref.maxInputChannels,
        dev.ref.maxOutputChannels,
      ]);
    }
  }

  void openStream() {
    Pointer<Pointer<Void>> ppStream = calloc<Pointer<Void>>();
    Pointer<PaTestData> pData = calloc.call<PaTestData>();
    int e = _pa.Pa_OpenDefaultStream(
      ppStream,
      0,
      2,
      paFloat32,
      96000,
      256,
      Pointer.fromFunction(_paCallback, 0),
      pData.cast<Void>(),
    );
    if (e != PaErrorCode.paNoError) throw Exception("Could not open Stream");
    Pointer<Void> pStream = ppStream.value;
    e = _pa.Pa_StartStream(pStream);
    if (e != PaErrorCode.paNoError) throw Exception("Could not start Stream");
  }

  static int _paCallback(
    Pointer<Void> input,
    Pointer<Void> output,
    int frameCount,
    Pointer<PaStreamCallbackTimeInfo> timeInfo,
    int statusFlags,
    Pointer<Void> userData,
  ) {
    print("call");
    /* Cast data passed through stream to our structure. */
    Pointer<PaTestData> data = userData.cast<PaTestData>();
    Pointer<Float> out = output.cast<Float>();
    int i;

    for (i = 0; i < frameCount; i++) {
      out.value = data.ref.left_phase; /* left */
      out = Pointer.fromAddress(out.address + 1);
      out.value = data.ref.right_phase; /* right */
      out = Pointer.fromAddress(out.address + 1);
      /* Generate simple sawtooth phaser that ranges between -1.0 and 1.0. */
      data.ref.left_phase += 0.01;
      /* When signal reaches top, drop back down. */
      if (data.ref.left_phase >= 1.0) data.ref.left_phase -= 2.0;
      /* higher pitch so we can distinguish left and right. */
      data.ref.right_phase += 0.03;
      if (data.ref.right_phase >= 1.0) data.ref.right_phase -= 2.0;
    }
    return 0;
  }
}

class PaTestData extends Struct {
  @Float()
  external double left_phase;
  @Float()
  external double right_phase;
}
