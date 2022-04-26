import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:ndiscopes/bindings/ndi_ffi_bindigs_v2.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:ndiscopes/bindings/pixconvert_cu_bindigs.dart';

NDIffi _ndi = NDIffi(DynamicLibrary.open("bin/Processing.NDI.Lib.x64.dll"));
PixconvertCUDA pixconvertCUDA = PixconvertCUDA(DynamicLibrary.open("bin/pixconvert_cu.dll"));

class NDI {
  /// A class wrapping around the NDI FFI bindings.
  NDI() {
    _ndi.NDIlib_v5_load();
    if (!_ndi.NDIlib_initialize()) {
      throw Exception("Could not initialize NDI");
    }
    _pRecv = _ndi.NDIlib_recv_create_v3(nullptr);
  }

  /// The internal pointer to the available NDI souces.
  ///
  /// Update this by calling [await updateSources()].
  Pointer<NDIlib_source_t>? _pSources;
  NDIlib_find_instance_t? _pFind;
  late Pointer<NDIlib_recv_instance_type> _pRecv;

  /// The List of [NDISource] containing available NDI sources.
  ///
  /// Update this by calling [await updateSources()].
  List<NDISource> sources = [];

  /// Get a source at a specific [index]
  Pointer<NDIlib_source_t>? getSourceAt(int index) {
    if (_pSources == null) return null;
    // every source takes up two memory slots: name and ipaddress
    return _pSources!.elementAt(index * 2);
  }

  /// Asynchronously update the [ndi.sources] list of NDI sources.
  ///
  /// Access updated sources with [ndi.sources] after waiting for this future to complete.
  Future<void> updateSoures() async {
    Completer completer = Completer();
    ReceivePort receivePort = ReceivePort();

    // create a new Isolate to update the pointer from another thread to prevent blocking of the UI thread
    Isolate iso = await Isolate.spawn(
      // function to execute on the thread
      _updateSourcePointer,

      _SMObject(
        receivePort.sendPort,
        // the find instance if one already exists
        _pFind?.address,
      ),
      debugName: "Source Isolate",
    );

    // listen for answers of the thread
    receivePort.listen(
      (data) {
        if (data is Map<String, int>) {
          // check that the data fields are present
          if (data["pSources"] == null || data["sourceCount"] == null) return;
          int sourceCount = data["sourceCount"]!;
          // clear old sources
          sources = [];

          // end if there are no sources found
          if (sourceCount == 0) {
            completer.complete();
            receivePort.close();
            iso.kill(priority: Isolate.immediate);
            return;
          }
          // get source pointer back from address
          _pSources = Pointer.fromAddress(data["pSources"]!).cast<NDIlib_source_t>();

          // add all found sources to the list accounting for the stride in memory
          for (int i = 0; i < sourceCount; i++) {
            sources.add(NDISource(_pSources!.elementAt(i * 2)));
          }
          completer.complete();
          receivePort.close();
          iso.kill(priority: Isolate.immediate);
        }
      },
      onDone: () {
        // isolate finished
      },
    );
    // return intermediate future until completed by completer
    return completer.future;
  }

  /// Invoked by the isolate in [updateSources()] to get a pointer to the new available ndi sources
  static void _updateSourcePointer(_SMObject object) {
    // create settings pointer with options
    Pointer<NDIlib_find_create_t> pCreateSettings = calloc.call<NDIlib_find_create_t>(1);
    pCreateSettings.ref.show_local_sources = 1;

    late NDIlib_find_instance_t pNDIfind;

    // either create new find instance or use one from previous searches if provided
    if (object.pFindA == null) {
      pNDIfind = _ndi.NDIlib_find_create2(pCreateSettings);
    } else {
      pNDIfind = Pointer.fromAddress(object.pFindA!);
    }

    // wait for 10s for new sources
    // if none detected send results to main thread
    if (!_ndi.NDIlib_find_wait_for_sources(pNDIfind, 10000)) {
      calloc.free(pCreateSettings);
      object.sendPort.send(<String, int>{
        "pSources": 0,
        "sourceCount": 0,
      });
      return;
    }
    // give the sdk more time in case there is more then one source.
    // otherwise would only find once source and return before other ones are detected
    sleep(const Duration(seconds: 1));

    // retrieve all found sources from the sdk
    final pSourceCount = calloc.call<Uint32>(1);
    final pSources = _ndi.NDIlib_find_get_current_sources(pNDIfind, pSourceCount);

    // send back results and pointer address to later free it
    object.sendPort.send(<String, int>{
      "pSources": pSources.address,
      "sourceCount": pSourceCount.value,
    });
    calloc.free(pCreateSettings);
    calloc.free(pSourceCount);
  }

  ReceivePort? _fReceivePort;
  Isolate? _fIsolate;
  SendPort? _fIsoSendport;

  /// sends updated mask properties to the receiving isolate if present
  ///
  /// [mask] is the Rect containing the mask position and size
  /// [active] is wheather to apply the mask to the input
  void updateMask(Rect mask, bool active) {
    if (_fIsoSendport != null) {
      // if sendport present/isolate active send mask properties
      // as Map<String,dynamic> to account for supported datatypes in isolate communication
      _fIsoSendport!.send({
        "mTop": mask.top,
        "mLeft": mask.left,
        "mWidth": mask.width,
        "mHeight": mask.height,
        "mActive": active,
      });
    }
  }

  /// A stream yielding the NDI Frames converted to an ui.Image.
  Future<void> getFrames(
    Pointer<NDIlib_source_t> source,
    Size scopeSize,
    Function(NDIOutputFrame frame) onFrame,
    Rect mask,
    bool maskActive,
  ) async {
    final completer = Completer();
    _fReceivePort = ReceivePort();

    // create the listener before starting the isolate to prevent missing the first messages
    _fReceivePort!.listen(
      (data) {
        if (data is Map<String, int>) {
          // check for data integrity and retreive pointers to frames from their addresses
          if (data["pRGBA"] != null &&
              data["width"] != null &&
              data["height"] != null &&
              data["pWF"] != null &&
              data["pWFRgb"] != null &&
              data["pWFParade"] != null &&
              data["pVScope"] != null &&
              data["pFalseC"] != null &&
              data["scopeWidth"] != null &&
              data["scopeHeight"] != null) {
            Pointer<Uint8> pRGBA = Pointer.fromAddress(data["pRGBA"]!);
            Pointer<Uint8> pWF = Pointer.fromAddress(data["pWF"]!);
            Pointer<Uint8> pWFRgb = Pointer.fromAddress(data["pWFRgb"]!);
            Pointer<Uint8> pWFParade = Pointer.fromAddress(data["pWFParade"]!);
            Pointer<Uint8> pVscope = Pointer.fromAddress(data["pVScope"]!);
            Pointer<Uint8> pFalseC = Pointer.fromAddress(data["pFalseC"]!);

            // convert every pointer to a Uint8List and convert that with wisth and height to a ui.Image
            // then free the pointers immediatly

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
                      ui.decodeImageFromPixels(pFalseC.asTypedList(data["width"]! * data["height"]! * 4),
                          data["width"]!, data["height"]!, ui.PixelFormat.rgba8888, (iFalseC) {
                        calloc.free(pFalseC);
                        onFrame(
                          NDIOutputFrame(
                            iRGBA: iRGBA,
                            iWF: iWF,
                            iWFRgb: iWFRgb,
                            iWFParade: iWFParade,
                            iVScope: iVScope,
                            iFalseC: iFalseC,
                          ),
                        );
                      });
                    });
                  });
                });
              });
            });
          }
        }
        // if the isolate send us its sendport for bidirectional communication store its reference
        // used for updating the mask inside the receiver thread
        if (data is SendPort) {
          _fIsoSendport = data;
        }
      },
      onDone: () {
        // complete the future once the Isolate has returned and receiving has stopped
        completer.complete();
      },
    );
    // create the isolate that continously receives NDI frames and finishes once stopGetFrames() is called
    _fIsolate = await Isolate.spawn(
      _getFrames,
      _FMObject(source.address, _pRecv.address, _fReceivePort!.sendPort, scopeSize, mask, maskActive),
      debugName: "Video Frame Isolate",
    );
    // return intermediate future until receiving has ended
    return completer.future;
  }

  /// stops the receiving thread and closes communication
  void stopGetFrames() {
    if (_fIsolate == null || _fReceivePort == null) return;
    _fReceivePort!.close();
    _fIsolate!.kill(priority: Isolate.immediate);
    _fIsolate = null;
    _fReceivePort = null;
    _fIsoSendport = null;
  }

  /// the function that gets executed by the receiver thread
  ///
  /// arguments are supplied in a custom object
  static void _getFrames(_FMObject object) async {
    ReceivePort rP = ReceivePort();
    Rect mask = object.mask;
    bool maskActive = object.maskActive;
    // send back the sendport for bidirectional communication
    object.sendPort.send(rP.sendPort);
    // listen for incoming messages from the main thread
    rP.listen(
      (message) {
        // new mask data as map
        if (message is Map<String, dynamic>) {
          if (message["mTop"] != null &&
              message["mLeft"] != null &&
              message["mWidth"] != null &&
              message["mHeight"] != null) {
            // update the mask data with new values
            mask = Rect.fromLTWH(message["mLeft"]!, message["mTop"]!, message["mWidth"]!, message["mHeight"]);
          }
          // toogle the mask if requested
          if (message["mActive"] != null) {
            maskActive = message["mActive"]!;
          }
        }
      },
      onDone: () {},
    );

    // Yey this got fixed by updating the NDI SDK to the most recent version
    //! NOPE
    // create the receiver settings
    /*Pointer<NDIlib_recv_create_v3_t> pCreateSettings = calloc.call<NDIlib_recv_create_v3_t>(1);
    // request a certain preferred color format
    pCreateSettings.ref.color_format = NDIlib_recv_color_format_e.NDIlib_recv_color_format_UYVY_BGRA;
    pCreateSettings.ref.bandwidth = NDIlib_recv_bandwidth_e.NDIlib_recv_bandwidth_highest;
    pCreateSettings.ref.source_to_connect_to = Pointer.fromAddress(object.pSourceA).cast<NDIlib_source_t>()[0];
    pCreateSettings.ref.p_ndi_recv_name = "NDIScopes".toNativeUtf8().cast<Int8>();
    pCreateSettings.ref.allow_video_fields = 0;*/

    // create the receiver instance
    //NDIlib_recv_instance_t pNDIrecv = _ndi.NDIlib_recv_create_v3(nullptr);
    NDIlib_recv_instance_t pNDIrecv = Pointer.fromAddress(object.pRecvA);
    //final pNDIRecv = Pointer.fromAddress(object.pRecvA).cast<NDIlib_recv_instance_t>();
    // get pointer of the desired source to receive from its address
    Pointer<NDIlib_source_t> pSource = Pointer.fromAddress(object.pSourceA);
    // connect to the source
    _ndi.NDIlib_recv_connect(pNDIrecv, pSource);
    // allocate the NDI video frame
    Pointer<NDIlib_video_frame_v2_t> pVideoFrame = calloc<NDIlib_video_frame_v2_t>();

    // initialize variables that are reused each loop
    int width = 0;
    int height = 0;
    // stores the type of the incoming frame -> NDIlib_frame_type_e
    int frame = -1;

    // receive until thread is killed
    while (true) {
      // give the async listener time to process incoming messages from main thread by interrupting the synchronous code
      await Future.delayed(Duration.zero);

      // get the frame type -> NDIlib_frame_type_e
      frame = _ndi.NDIlib_recv_capture_v3(pNDIrecv, pVideoFrame, nullptr, nullptr, 200);
      // ignore the frame if it is not a video frame
      if (frame != NDIlib_frame_type_e.NDIlib_frame_type_video) continue;
      width = pVideoFrame.ref.xres;
      height = pVideoFrame.ref.yres;
      // allocate memory for the rgba frame and all the scopes/waveforms
      Pointer<Uint8> pRGBA = calloc.call<Uint8>(width * height * 4);
      Pointer<Uint8> pWF = calloc.call<Uint8>(object.scopeSize.width.toInt() * object.scopeSize.height.toInt() * 4);
      Pointer<Uint8> pWFRgb = calloc.call<Uint8>(object.scopeSize.width.toInt() * object.scopeSize.height.toInt() * 4);
      Pointer<Uint8> pWFParade =
          calloc.call<Uint8>(object.scopeSize.width.toInt() * object.scopeSize.height.toInt() * 4);
      Pointer<Uint8> pVScope =
          calloc.call<Uint8>(object.scopeSize.height.toInt() * object.scopeSize.height.toInt() * 4);
      Pointer<Uint8> pFalseC = calloc.call<Uint8>(width * height * 4);

      // convert to rgba pointers based on the format
      switch (pVideoFrame.ref.FourCC) {
        case NDIlib_FourCC_video_type_e.NDIlib_FourCC_type_UYVY:
          // apply mask if active to source to reflect it on all scopes
          if (maskActive) {
            //! replace with CPU/GPU compatible
            pixconvertCUDA.rectMaskFrame(Size(width.toDouble(), height.toDouble()), mask, pVideoFrame.ref.p_data, 1);
          }
          //! replace with CPU/GPU compatible
          pixconvertCUDA.uyvyToScopes(
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
            pFalseC,
          );
          break;
        case NDIlib_FourCC_video_type_e.NDIlib_FourCC_type_BGRA:
          // apply mask if active to source to reflect it on all scopes
          if (maskActive) {
            //! replace with CPU/GPU compatible
            pixconvertCUDA.rectMaskFrame(Size(width.toDouble(), height.toDouble()), mask, pVideoFrame.ref.p_data, 2);
          }
          //! replace with CPU/GPU compatible
          pixconvertCUDA.bgraToScopes(
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
            pFalseC,
          );
          break;
        default:
          // ignore: avoid_print
          print("unsupported format");
      }
      // free the source pointer!!!
      _ndi.NDIlib_recv_free_video_v2(pNDIrecv, pVideoFrame);

      // send results back to main thread that will free the rgba pointers
      object.sendPort.send(<String, int>{
        "width": width,
        "height": height,
        "pRGBA": pRGBA.address,
        "pWF": pWF.address,
        "pWFRgb": pWFRgb.address,
        "pWFParade": pWFParade.address,
        "pVScope": pVScope.address,
        "pFalseC": pFalseC.address,
        "scopeWidth": object.scopeSize.width.toInt(),
        "scopeHeight": object.scopeSize.height.toInt(),
      });

      //receive next frame
    }
  }

  ReceivePort? _sfReceivePort;

  /// the same as getFrames but doesn't loop so only returns one frame as SavedInputFrame to be stored in a file
  Future<void> getSingleFrame(
    Pointer<NDIlib_source_t> pSource,
    Size scopeSize,
    Function(SavedInputFrame frame) onFrameReady,
    Rect mask,
    bool maskActive,
  ) async {
    final completer = Completer();
    _sfReceivePort = ReceivePort();
    await Isolate.spawn(
      _getSingleFrame,
      _FMObject(pSource.address, _pRecv.address, _sfReceivePort!.sendPort, scopeSize, mask, maskActive),
      debugName: "get Single Frame Isolate",
    );
    _sfReceivePort!.listen((data) {
      if (data is Map<String, int>) {
        if (data["width"] != null && data["height"] != null && data["pVideo"] != null && data["pNDIRecv"] != null) {
          int width = data["width"]!;
          int height = data["height"]!;
          NDIInputFormat format = NDIInputFormat.values[data["format"]!];
          final pVideoFrame = Pointer.fromAddress(data["pVideo"]!).cast<NDIlib_video_frame_v2_t>();
          final pNDIRecv = Pointer.fromAddress(data["pNDIRecv"]!).cast<NDIlib_recv_instance_type>();

          int bytesPerPixel = 0;
          switch (format) {
            case NDIInputFormat.bgra:
              bytesPerPixel = 4;
              break;
            case NDIInputFormat.uyvy:
              bytesPerPixel = 2;
              break;
            default:
              bytesPerPixel = 4;
              break;
          }

          Uint8List bytes = Uint8List.fromList(pVideoFrame.ref.p_data.asTypedList(width * height * bytesPerPixel));
          _ndi.NDIlib_recv_free_video_v2(pNDIRecv, pVideoFrame);
          onFrameReady(
              SavedInputFrame(bytes: bytes, width: width, height: height, format: format, timestamp: DateTime.now()));
        }
      }
    });
    return completer.future;
  }

  static void _getSingleFrame(_FMObject object) {
    NDIlib_recv_instance_t pNDIrecv = Pointer.fromAddress(object.pRecvA);
    Pointer<NDIlib_source_t> pSource = Pointer.fromAddress(object.pSourceA).cast<NDIlib_source_t>();
    _ndi.NDIlib_recv_connect(pNDIrecv, pSource);

    Pointer<NDIlib_video_frame_v2_t> pVideoFrame = calloc<NDIlib_video_frame_v2_t>();

    int width = 0;
    int height = 0;

    int frame = -1;
    int i = 0;
    NDIInputFormat format = NDIInputFormat.uyvy;

    while (frame != NDIlib_frame_type_e.NDIlib_frame_type_video && i < 50) {
      i++;
      frame = _ndi.NDIlib_recv_capture_v3(pNDIrecv, pVideoFrame, nullptr, nullptr, 200);

      if (frame != NDIlib_frame_type_e.NDIlib_frame_type_video) continue;
      //if (pVideoFrame.ref.FourCC != NDIlib_FourCC_video_type_e.NDIlib_FourCC_type_UYVY) continue;
      width = pVideoFrame.ref.xres;
      height = pVideoFrame.ref.yres;
      switch (pVideoFrame.ref.FourCC) {
        case NDIlib_FourCC_video_type_e.NDIlib_FourCC_type_UYVY:
          format = NDIInputFormat.uyvy;
          break;
        case NDIlib_FourCC_video_type_e.NDIlib_FourCC_type_BGRA:
          format = NDIInputFormat.bgra;
          break;
        default:
          // ignore: avoid_print
          print("unsupported format");
      }
      object.sendPort.send(<String, int>{
        "width": width,
        "height": height,
        "pVideo": pVideoFrame.address,
        "pNDIRecv": pNDIrecv.address,
        "format": format.index,
      });
    }
  }

  Isolate? _aIsolate;
  ReceivePort? _aReceiveport;

  Future<void> getAudio(
    Pointer<NDIlib_source_t> source,
    Function(NDIAudioLevelFrame level) onLevel,
  ) async {
    final completer = Completer();

    _aReceiveport = ReceivePort();

    _aReceiveport!.listen((data) {
      if (data is NDIAudioLevelFrame) {
        onLevel(data);
      }
    }, onDone: (() {
      completer.complete();
    }));

    _aIsolate = await Isolate.spawn(
      _getAudio,
      _AMObject(_aReceiveport!.sendPort, source.address, _pRecv.address),
    );

    return completer.future;
  }

  void stopGetAudio() {
    _aReceiveport?.close();
    _aIsolate?.kill(priority: Isolate.immediate);
    _aIsolate = null;
    _aReceiveport = null;
  }

  static void _getAudio(_AMObject object) async {
    NDIlib_recv_instance_t pNDIrecv = Pointer.fromAddress(object.pRecvA);
    //final pNDIRecv = Pointer.fromAddress(object.pRecvA).cast<NDIlib_recv_instance_t>();
    // get pointer of the desired source to receive from its address
    //Pointer<NDIlib_source_t> pSource = Pointer.fromAddress(object.pSourceA);
    // connect to the source
    //! no need since already connected by video frame isolate
    //_ndi.NDIlib_recv_connect(pNDIrecv, pSource);

    Pointer<NDIlib_audio_frame_v2_t> pAudioFrame = calloc<NDIlib_audio_frame_v2_t>();

    int frame = -1;

    while (true) {
      await Future.delayed(const Duration(milliseconds: 100));
      frame = _ndi.NDIlib_recv_capture_v2(pNDIrecv, nullptr, pAudioFrame, nullptr, 1000);
      if (frame != NDIlib_frame_type_e.NDIlib_frame_type_audio) continue;
      int channels = pAudioFrame.ref.no_channels;
      int samples = pAudioFrame.ref.no_samples;
      int stride = pAudioFrame.ref.channel_stride_in_bytes;
      Pointer<Float> data = pAudioFrame.ref.p_data;
      object.sendPort.send(
        NDIAudioLevelFrame(
          channelLevels: List<double>.generate(channels, (index) {
            return data.elementAt(index * stride ~/ 4).asTypedList(samples).reduce(
                  (a, b) => max(
                    a.abs(),
                    b.abs(),
                  ),
                );
          }),
        ),
      );
      _ndi.NDIlib_recv_free_audio_v2(pNDIrecv, pAudioFrame);
    }
  }
}

class _AMObject {
  SendPort sendPort;
  int pRecvA;
  int pSourceA;
  _AMObject(this.sendPort, this.pSourceA, this.pRecvA);
}

/// the object used for initializing thread with parameters to find new sources
class _SMObject {
  SendPort sendPort;
  int? pFindA;
  _SMObject(this.sendPort, this.pFindA);
}

/// the object used for initializing thread with parameters to receive frames
class _FMObject {
  int pSourceA;
  int pRecvA;
  SendPort sendPort;
  Size scopeSize;
  Rect mask;
  bool maskActive;
  _FMObject(this.pSourceA, this.pRecvA, this.sendPort, this.scopeSize, this.mask, this.maskActive);
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

/// A class storing all [ui.Image]s required to paint the frame and all the scopes
///
class NDIOutputFrame {
  ui.Image iRGBA;
  ui.Image iWF;
  ui.Image iWFRgb;
  ui.Image iWFParade;
  ui.Image iVScope;
  ui.Image iFalseC;
  NDIOutputFrame({
    required this.iRGBA,
    required this.iWF,
    required this.iWFRgb,
    required this.iWFParade,
    required this.iVScope,
    required this.iFalseC,
  });
}

/// Enumarator to distinguish between different formats that incoming or outgoing NDI frames might appear in
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

/// A class that represents a frame that can be stored as a file or read from a file (.ndis)
///
/// It contains the raw [bytes] of the frame provided from the NDI SDK in the specified [format]
///
/// It also stores the [width] and [height] of the frame to reconstruct it from a 1D list of bytes.
class SavedInputFrame {
  NDIInputFormat format;
  Uint8List bytes;
  int width;
  int height;
  DateTime timestamp;
  Uint8List? thumbnail;

  SavedInputFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
    required this.timestamp,
    this.thumbnail,
  });

  /// Renders a thumbnail image from the bytes of the frame if it's in UYVY format and stores it in the [thumbnail] property
  ///
  /// If [thumbnail] is already present it will not be rendered again and just returned as a [ui.Image].
  Future<ui.Image?> thumbnailImage() {
    final c = Completer<ui.Image?>();
    if (format != NDIInputFormat.uyvy && format != NDIInputFormat.bgra) {
      c.complete(null);
      return c.future;
    }
    if (thumbnail == null) {
      // allocate byte pointer with same length as bytes for srouce frame
      Pointer<Uint8> pSrc = calloc.call<Uint8>(bytes.length);
      // copy source bytes into pointer
      pSrc.asTypedList(bytes.length).setAll(0, bytes);
      // allocate byte pointer with dimensions of the thumbnail for thumbnail frame (*4 for RGBA)
      Pointer<Uint8> pTn = calloc.call<Uint8>(160 * 90 * 4);
      // create thumbnail from source in CUDA
      //! replace with CPU/GPU compatible
      switch (format) {
        case NDIInputFormat.bgra:
          pixconvertCUDA.thumbnailFromBgra(pSrc, width, height, pTn, 160, 90);
          break;
        case NDIInputFormat.uyvy:
          pixconvertCUDA.thumbnailFromUyvy(pSrc, width, height, pTn, 160, 90);
          break;
        default:
      }

      // create ui.Image from rgba pointer
      ui.decodeImageFromPixels(
        pTn.asTypedList(160 * 90 * 4),
        160,
        90,
        ui.PixelFormat.rgba8888,
        (result) {
          // store thumbnail bytes for later to prevent re-rendering
          thumbnail = Uint8List.fromList(pTn.asTypedList(160 * 90 * 4));
          // free all pointers (no memory leaks here)
          calloc.free(pSrc);
          calloc.free(pTn);
          // return ui.Image of thumbnail
          c.complete(result);
        },
      );
    } else {
      // if thumbnail bytes present just convert to ui.Image
      ui.decodeImageFromPixels(thumbnail!, 160, 90, ui.PixelFormat.rgba8888, (result) {
        // return ui.Image of thumbnail
        c.complete(result);
      });
    }
    // return intermediate future until completed above
    return c.future;
  }

  /// Renders all frames necessary to draw the source and all scopes/waveforms
  ///
  /// provide desired width and height of the scopes
  Future<NDIOutputFrame?> convertToScopes(int scopeWidth, int scopeHeight) {
    final c = Completer<NDIOutputFrame?>();

    // create all necessary pointers with desired dimesions *4 (4 Bytes RGBA)
    Pointer<Uint8> pSrc = calloc.call<Uint8>(bytes.length);
    Pointer<Uint8> pRGBA = calloc.call<Uint8>(width * height * 4);
    Pointer<Uint8> pWF = calloc.call<Uint8>(scopeWidth * scopeHeight * 4);
    Pointer<Uint8> pWFRgb = calloc.call<Uint8>(scopeWidth * scopeHeight * 4);
    Pointer<Uint8> pWFParade = calloc.call<Uint8>(scopeWidth * scopeHeight * 4);
    Pointer<Uint8> pVScope = calloc.call<Uint8>(scopeHeight * scopeHeight * 4);
    Pointer<Uint8> pFalseC = calloc.call<Uint8>(width * height * 4);

    // copy source bytes into pointer
    pSrc.asTypedList(bytes.length).setAll(0, bytes);

    // use different convert method based on input frame format
    switch (format) {
      case NDIInputFormat.uyvy:
        //! replace with CPU/GPU compatible
        pixconvertCUDA.uyvyToScopes(
            width, height, pSrc, pRGBA, scopeWidth, scopeHeight, pWF, pWFRgb, pWFParade, pVScope, pFalseC);
        break;
      case NDIInputFormat.bgra:
        //! replace with CPU/GPU compatible
        pixconvertCUDA.bgraToScopes(
            width, height, pSrc, pRGBA, scopeWidth, scopeHeight, pWF, pWFRgb, pWFParade, pVScope, pFalseC);
        break;
      default:
        c.complete(null);
        return c.future;
    }
    // convert from rgba bytes in pointers to ui.Image then free the pointers
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
              // return the finished frames
              ui.decodeImageFromPixels(pFalseC.asTypedList(width * height * 4), width, height, ui.PixelFormat.rgba8888,
                  (iFalseC) {
                calloc.free(pFalseC);
                c.complete(
                  NDIOutputFrame(
                    iRGBA: iRGBA,
                    iWF: iWF,
                    iWFRgb: iWFRgb,
                    iWFParade: iWFParade,
                    iVScope: iVScope,
                    iFalseC: iFalseC,
                  ),
                );
              });
            });
          });
        });
      });
    });
    // return intermediate future until completed above
    return c.future;
  }

  /// Converts this to a json encodable map
  ///
  /// Get json String by using [json.encode(result)]
  Map<String, dynamic> toJSON() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'width': width,
      'height': height,
      'bytes': base64.encode(bytes),
      'format': format.index,
      'thumbnail': thumbnail != null ? base64.encode(thumbnail!) : null,
    };
  }

  /// Creates instance from a json decoded map
  factory SavedInputFrame.fromJSON(Map<String, dynamic> json) {
    return SavedInputFrame(
      bytes: json['bytes'] != null ? base64.decode(json['bytes']) : Uint8List.fromList([0]),
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
      format: NDIInputFormat.values[json['format'] ?? 0],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? 0),
      thumbnail: json['thumbnail'] != null ? base64.decode(json['thumbnail']) : null,
    );
  }
}

class NDIAudioLevelFrame {
  List<double> channelLevels;

  NDIAudioLevelFrame({required this.channelLevels});
}
