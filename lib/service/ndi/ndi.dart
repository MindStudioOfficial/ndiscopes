import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:ndiscopes/bindings/ndi_ffi_bindigs.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:convert';
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
    return _pSources!.elementAt(index * 2);
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
            sources.add(NDISource(_pSources!.elementAt(i * 2)));
          }
          completer.complete();
          receivePort.close();
          iso.kill(priority: Isolate.immediate);
        }
      },
      onDone: () {},
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
    sleep(const Duration(seconds: 1));

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
  Future<void> getFrames(
      Pointer<NDIlib_source_t> source, Size scopeSize, Function(NDIOutputFrame frame) onFrame) async {
    final completer = Completer();
    _fReceivePort = ReceivePort();
    _fIsolate = await Isolate.spawn(_getFrames, _FMObject(source.address, _fReceivePort!.sendPort, scopeSize));
    _fReceivePort!.listen(
      (data) {
        if (data is Map<String, int>) {
          if (data["pRGBA"] != null &&
              data["width"] != null &&
              data["height"] != null &&
              data["pWF"] != null &&
              data["pWFRgb"] != null &&
              data["pWFParade"] != null &&
              data["pVScope"] != null &&
              data["scopeWidth"] != null &&
              data["scopeHeight"] != null) {
            Pointer<Uint8> pRGBA = Pointer.fromAddress(data["pRGBA"]!);
            Pointer<Uint8> pWF = Pointer.fromAddress(data["pWF"]!);
            Pointer<Uint8> pWFRgb = Pointer.fromAddress(data["pWFRgb"]!);
            Pointer<Uint8> pWFParade = Pointer.fromAddress(data["pWFParade"]!);
            Pointer<Uint8> pVscope = Pointer.fromAddress(data["pVScope"]!);

            Uint8List pxs = pRGBA.asTypedList(data["width"]! * data["height"]! * 4);
            int scopeWidth = data["scopeWidth"]!;
            int scopeHeight = data["scopeHeight"]!;

            ui.decodeImageFromPixels(pxs, data["width"]!, data["height"]!, ui.PixelFormat.rgba8888, (iRGBA) {
              calloc.free(pRGBA);
              ui.decodeImageFromPixels(
                  pWF.asTypedList(scopeWidth * scopeHeight * 4), scopeWidth, scopeHeight, ui.PixelFormat.rgba8888,
                  (iWF) {
                calloc.free(pWF);
                ui.decodeImageFromPixels(
                    pWFRgb.asTypedList(scopeWidth * scopeHeight * 4), scopeWidth, scopeHeight, ui.PixelFormat.rgba8888,
                    (iWFRgb) {
                  calloc.free(pWFRgb);
                  ui.decodeImageFromPixels(pWFParade.asTypedList(scopeWidth * scopeHeight * 4), scopeWidth, scopeHeight,
                      ui.PixelFormat.rgba8888, (iWFParade) {
                    calloc.free(pWFParade);
                    ui.decodeImageFromPixels(pVscope.asTypedList(scopeHeight * scopeHeight * 4), scopeHeight,
                        scopeHeight, ui.PixelFormat.rgba8888, (iVScope) {
                      calloc.free(pVscope);
                      onFrame(NDIOutputFrame(
                          iRGBA: iRGBA, iWF: iWF, iWFRgb: iWFRgb, iWFParade: iWFParade, iVScope: iVScope));
                    });
                  });
                });
              });
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
      Pointer<Uint8> pWF = calloc.call<Uint8>(object.scopeSize.width.toInt() * object.scopeSize.height.toInt() * 4);
      Pointer<Uint8> pWFRgb = calloc.call<Uint8>(object.scopeSize.width.toInt() * object.scopeSize.height.toInt() * 4);
      Pointer<Uint8> pWFParade =
          calloc.call<Uint8>(object.scopeSize.width.toInt() * object.scopeSize.height.toInt() * 4);
      Pointer<Uint8> pVScope =
          calloc.call<Uint8>(object.scopeSize.height.toInt() * object.scopeSize.height.toInt() * 4);

      switch (pVideoFrame.ref.FourCC) {
        case NDIlib_FourCC_video_type_e.NDIlib_FourCC_type_UYVY:
          _pixconvertCUDA.uyvyToScopes(
            width,
            height,
            pVideoFrame.ref.p_data,
            pRGBA,
            object.scopeSize.width.toInt(),
            object.scopeSize.height.toInt(),
            pWF,
            pWFRgb,
            pWFParade,
            pVScope,
          );
          break;
        default:
          print("unsupported format");
      }
      _ndi.NDIlib_recv_free_video_v2(pNDIrecv, pVideoFrame);
      object.sendPort.send(<String, int>{
        "width": width,
        "height": height,
        "pRGBA": pRGBA.address,
        "pWF": pWF.address,
        "pWFRgb": pWFRgb.address,
        "pWFParade": pWFParade.address,
        "pVScope": pVScope.address,
        "scopeWidth": object.scopeSize.width.toInt(),
        "scopeHeight": object.scopeSize.height.toInt(),
      });
    }
  }

  ReceivePort? _sfReceivePort;
  Isolate? _sfIsolate;
  Future<void> getSingleFrame(
      Pointer<NDIlib_source_t> pSource, Size scopeSize, Function(SavedInputFrame frame) onFrameReady) async {
    final completer = Completer();
    _sfReceivePort = ReceivePort();
    _sfIsolate = await Isolate.spawn(_getSingleFrame, _FMObject(pSource.address, _sfReceivePort!.sendPort, scopeSize));
    _sfReceivePort!.listen((data) {
      if (data is Map<String, int>) {
        if (data["width"] != null && data["height"] != null && data["pVideo"] != null && data["pNDIRecv"] != null) {
          int width = data["width"]!;
          int height = data["height"]!;
          final pVideoFrame = Pointer.fromAddress(data["pVideo"]!).cast<NDIlib_video_frame_v2_t>();
          final pNDIRecv = Pointer.fromAddress(data["pNDIRecv"]!).cast<Void>();

          Uint8List bytes = Uint8List.fromList(pVideoFrame.ref.p_data.asTypedList(width * height * 2));
          _ndi.NDIlib_recv_free_video_v2(pNDIRecv, pVideoFrame);
          onFrameReady(SavedInputFrame(
              bytes: bytes, width: width, height: height, format: NDIInputFormat.uyvy, timestamp: DateTime.now()));
        }
      }
    });
    return completer.future;
  }

  static void _getSingleFrame(_FMObject object) {
    NDIlib_recv_instance_t pNDIrecv = _ndi.NDIlib_recv_create_v3(nullptr);
    Pointer<NDIlib_source_t> pSource = Pointer.fromAddress(object.pSourceA).cast<NDIlib_source_t>();
    _ndi.NDIlib_recv_connect(pNDIrecv, pSource);

    Pointer<NDIlib_video_frame_v2_t> pVideoFrame = calloc<NDIlib_video_frame_v2_t>();
    int width = 0;
    int height = 0;

    int frame = -1;
    int i = 0;

    while (frame != NDIlib_frame_type_e.NDIlib_frame_type_video && i < 50) {
      i++;
      frame = _ndi.NDIlib_recv_capture_v3(pNDIrecv, pVideoFrame, nullptr, nullptr, 200);
      if (frame != NDIlib_frame_type_e.NDIlib_frame_type_video) continue;
      if (pVideoFrame.ref.FourCC != NDIlib_FourCC_video_type_e.NDIlib_FourCC_type_UYVY) continue;
      width = pVideoFrame.ref.xres;
      height = pVideoFrame.ref.yres;
      object.sendPort.send(<String, int>{
        "width": width,
        "height": height,
        "pVideo": pVideoFrame.address,
        "pNDIRecv": pNDIrecv.address,
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
  Size scopeSize;
  _FMObject(this.pSourceA, this.sendPort, this.scopeSize);
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

class NDIOutputFrame {
  ui.Image iRGBA;
  ui.Image iWF;
  ui.Image iWFRgb;
  ui.Image iWFParade;
  ui.Image iVScope;
  NDIOutputFrame(
      {required this.iRGBA, required this.iWF, required this.iWFRgb, required this.iWFParade, required this.iVScope});
}

enum NDIInputFormat {
  uyvy,
  uyva,
  rgba,
  rgbx,
  bgra,
  i420,
  nv12,
  p216,
  pa16,
  yv12,
}

class SavedInputFrame {
  NDIInputFormat format;
  Uint8List bytes;
  int width;
  int height;
  DateTime timestamp;

  SavedInputFrame(
      {required this.bytes, required this.width, required this.height, required this.format, required this.timestamp});

  Future<NDIOutputFrame?> convertToScopes(int scopeWidth, int scopeHeight) {
    final c = Completer<NDIOutputFrame?>();
    if (format == NDIInputFormat.uyvy) {
      Pointer<Uint8> pSrc = calloc.call<Uint8>(width * height * 2);
      for (int i = 0; i < bytes.length; i++) {
        pSrc[i] = bytes[i];
      }
      Pointer<Uint8> pRGBA = calloc.call<Uint8>(width * height * 4);
      Pointer<Uint8> pWF = calloc.call<Uint8>(width * height * 4);
      Pointer<Uint8> pWFRgb = calloc.call<Uint8>(width * height * 4);
      Pointer<Uint8> pWFParade = calloc.call<Uint8>(width * height * 4);
      Pointer<Uint8> pVScope = calloc.call<Uint8>(width * height * 4);

      _pixconvertCUDA.uyvyToScopes(
          width, height, pSrc, pRGBA, scopeWidth, scopeHeight, pWF, pWFRgb, pWFParade, pVScope);

      ui.decodeImageFromPixels(pRGBA.asTypedList(width * height * 4), width, height, ui.PixelFormat.rgba8888, (iRGBA) {
        calloc.free(pRGBA);
        ui.decodeImageFromPixels(
            pWF.asTypedList(scopeWidth * scopeHeight * 4), scopeWidth, scopeHeight, ui.PixelFormat.rgba8888, (iWF) {
          calloc.free(pWF);
          ui.decodeImageFromPixels(
              pWFRgb.asTypedList(scopeWidth * scopeHeight * 4), scopeWidth, scopeHeight, ui.PixelFormat.rgba8888,
              (iWFRgb) {
            calloc.free(pWFRgb);
            ui.decodeImageFromPixels(
                pWFParade.asTypedList(scopeWidth * scopeHeight * 4), scopeWidth, scopeHeight, ui.PixelFormat.rgba8888,
                (iWFParade) {
              calloc.free(pWFParade);
              ui.decodeImageFromPixels(
                  pVScope.asTypedList(scopeHeight * scopeHeight * 4), scopeHeight, scopeHeight, ui.PixelFormat.rgba8888,
                  (iVScope) {
                calloc.free(pVScope);
                c.complete(
                    NDIOutputFrame(iRGBA: iRGBA, iWF: iWF, iWFRgb: iWFRgb, iWFParade: iWFParade, iVScope: iVScope));
              });
            });
          });
        });
      });
    } else {
      c.complete(null);
    }
    return c.future;
  }

  Map<String, dynamic> toJSON() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'width': width,
      'height': height,
      'bytes': base64.encode(bytes),
      'format': format.index,
    };
  }

  factory SavedInputFrame.fromJSON(Map<String, dynamic> json) {
    return SavedInputFrame(
      bytes: json['bytes'] != null ? base64.decode(json['bytes']) : Uint8List.fromList([0]),
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
      format: NDIInputFormat.values[json['format'] ?? 0],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? 0),
    );
  }
}
