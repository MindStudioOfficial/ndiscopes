import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:ndiscopes/bindings/ndi_ffi_bindigs.dart';
import 'dart:ui' as ui;

import 'package:ndiscopes/bindings/pixconvert_cu_bindigs.dart';

NDIffi _ndi = NDIffi(DynamicLibrary.open("bin/Processing.NDI.Lib.x64.dll"));
PixconvertCUDA _pixconvertCUDA = PixconvertCUDA(DynamicLibrary.open("bin/pixconvert_cu.dll"));

class NDI {
  /// A class wrapping around the NDI FFI bindings.
  NDI() {
    _ndi.NDIlib_v5_load();
    if (!_ndi.NDIlib_initialize()) {
      throw Exception("Could not initialize NDI");
    }
  }

  /// The internal pointer to the available NDI souces.
  ///
  /// Update this by calling [await updateSources()].
  Pointer<NDIlib_source_t>? _pSources;
  NDIlib_find_instance_t? _pFind;

  /// The List of [NDISource] containing available NDI sources.
  ///
  /// Update this by calling [await updateSources()].
  List<NDISource> sources = [];

  Pointer<NDIlib_source_t>? getSourceAt(int index) {
    if (_pSources == null) return null;
    return _pSources!.elementAt(index);
  }

  /// Asynchronously update the [ndi.sources] list of NDI sources.
  ///
  /// Access updated sources with [ndi.sources] after waiting for this future to complete.
  Future<void> updateSoures() async {
    Completer completer = Completer();
    ReceivePort receivePort = ReceivePort();
    Isolate iso = await Isolate.spawn(
        _updateSourcePointer, _SMObject(receivePort.sendPort, _pFind != null ? _pFind!.address : null));
    receivePort.listen(
      (data) {
        if (data is Map<String, int>) {
          if (data["pSources"] == null || data["sourceCount"] == null) return;
          int sourceCount = data["sourceCount"]!;
          _pSources = Pointer.fromAddress(data["pSources"]!).cast<NDIlib_source_t>();
          sources = [];
          for (int i = 0; i < sourceCount; i++) {
            sources.add(NDISource(_pSources!.elementAt(i)));
          }
          completer.complete();
          receivePort.close();
          iso.kill(priority: Isolate.immediate);
        }
      },
      onDone: () {
        print("done finding sources");
      },
    );
    return completer.future;
  }

  /// Invoked by the isolate in [updateSources()] to get a pointer to the new available ndi sources
  static void _updateSourcePointer(_SMObject object) {
    Pointer<NDIlib_find_create_t> pCreateSettings = calloc.call<NDIlib_find_create_t>(1);
    pCreateSettings.ref.show_local_sources = 1;

    late NDIlib_find_instance_t pNDIfind;
    if (object.pFindA == null) {
      pNDIfind = _ndi.NDIlib_find_create2(pCreateSettings);
    } else {
      pNDIfind = Pointer.fromAddress(object.pFindA!);
    }
    if (!_ndi.NDIlib_find_wait_for_sources(pNDIfind, 10000)) {
      calloc.free(pCreateSettings);
      return;
    }

    final pSourceCount = calloc.call<Uint32>(1);
    final pSources = _ndi.NDIlib_find_get_current_sources(pNDIfind, pSourceCount);
    object.sendPort.send(<String, int>{
      "pSources": pSources.address,
      "sourceCount": pSourceCount.value,
    });

    calloc.free(pCreateSettings);
    calloc.free(pSourceCount);
  }

  ReceivePort? _fReceivePort;
  Isolate? _fIsolate;

  /// A stream yielding the NDI Frames converted to an ui.Image.
  Future<void> getFrames(Pointer<NDIlib_source_t> source, Function(NDIFrame frame) onFrame) async {
    final completer = Completer();
    _fReceivePort = ReceivePort();
    _fIsolate = await Isolate.spawn(_getFrames, _FMObject(source.address, _fReceivePort!.sendPort));
    _fReceivePort!.listen(
      (data) {
        if (data is Map<String, int>) {
          if (data["pRGBA"] != null && data["width"] != null && data["height"] != null) {
            Pointer<Uint8> pRGBA = Pointer.fromAddress(data["pRGBA"]!);
            Uint8List pxs = pRGBA.asTypedList(data["width"]! * data["height"]! * 4);

            ui.decodeImageFromPixels(pxs, data["width"]!, data["height"]!, ui.PixelFormat.rgba8888, (result) {
              calloc.free(pRGBA);
              onFrame(NDIFrame(iRGBA: result));
            });
          }
        }
      },
      onDone: () {
        completer.complete();
      },
    );
    return completer.future;
  }

  void stopGetFrames() {
    if (_fIsolate == null || _fReceivePort == null) return;
    _fReceivePort!.close();
    _fIsolate!.kill(priority: Isolate.immediate);
    _fIsolate = null;
    _fReceivePort = null;
  }

  static void _getFrames(_FMObject object) {
    NDIlib_recv_instance_t pNDIrecv = _ndi.NDIlib_recv_create_v3(nullptr);
    Pointer<NDIlib_source_t> pSource = Pointer.fromAddress(object.pSourceA);
    _ndi.NDIlib_recv_connect(pNDIrecv, pSource);

    Pointer<NDIlib_video_frame_v2_t> pVideoFrame = calloc<NDIlib_video_frame_v2_t>();
    int width = 0;
    int height = 0;

    int frame = -1;

    while (true) {
      frame = _ndi.NDIlib_recv_capture_v3(pNDIrecv, pVideoFrame, nullptr, nullptr, 200);
      if (frame != NDIlib_frame_type_e.NDIlib_frame_type_video) continue;
      width = pVideoFrame.ref.xres;
      height = pVideoFrame.ref.yres;

      Pointer<Uint8> pRGBA = calloc.call<Uint8>(width * height * 4);

      switch (pVideoFrame.ref.FourCC) {
        case NDIlib_FourCC_video_type_e.NDIlib_FourCC_type_UYVY:
          _pixconvertCUDA.uyvyToRGBA(width, height, pVideoFrame.ref.p_data, pRGBA);
          break;
        default:
          print("unsupported format");
      }
      _ndi.NDIlib_recv_free_video_v2(pNDIrecv, pVideoFrame);
      object.sendPort.send(<String, int>{
        "width": width,
        "height": height,
        "pRGBA": pRGBA.address,
      });
    }
  }
}

class _SMObject {
  SendPort sendPort;
  int? pFindA;
  _SMObject(this.sendPort, this.pFindA);
}

class _FMObject {
  int pSourceA;
  SendPort sendPort;
  _FMObject(this.pSourceA, this.sendPort);
}

/// A class wrapping around the internal [NDIlib_source_t] type.
///
/// Access a sources name with the [name] property.
class NDISource {
  Pointer<NDIlib_source_t> source;
  NDISource(this.source);

  /// Access the name of the given NDI source.
  String get name {
    return source.ref.p_ndi_name.cast<Utf8>().toDartString();
  }

  @override
  String toString() {
    return name;
  }
}

class NDIFrame {
  ui.Image iRGBA;
  NDIFrame({required this.iRGBA});
}
