import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:ffi/ffi.dart' as ffi;
import 'package:flutter/foundation.dart';
import 'package:ndiscopes/bindings/ndi_ffi_bindigs_v2.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:ndiscopes/bindings/scopes_bindings_v1.dart';
import 'package:ndiscopes/providers/providers.dart';
import 'package:ndiscopes/service/audio/audio.dart';
import 'package:ndiscopes/service/textures/textures.dart';
import 'package:ndiscopes/util/datetimetostring.dart';

import 'package:ndiscopes/service/ndi/ndisource.dart';
import 'package:ndiscopes/service/ndi/savedinputframe.dart';

export 'package:ndiscopes/service/ndi/ndisource.dart';
export 'package:ndiscopes/service/ndi/ndioutputframe.dart';
export 'package:ndiscopes/service/ndi/savedinputframe.dart';

NDIffi _ndi = NDIffi(DynamicLibrary.open("bin/Processing.NDI.Lib.x64.dll"));
ScopesFFI scopes = ScopesFFI(DynamicLibrary.open("bin/scopes.dll"));

late NDI ndi;

class NDI {
  /// A class wrapping around the NDI FFI bindings.
  NDI() {
    _ndi.NDIlib_v5_load();
    if (!_ndi.NDIlib_initialize()) {
      throw Exception("Could not initialize NDI");
    }
    _printNDI("Library initialized");

    _pRecv = _ndi.NDIlib_recv_create_v3(nullptr);
  }

  /// The internal pointer to the available NDI souces.
  ///
  /// Update this by calling [await updateSources()].
  Pointer<NDIlib_source_t>? _pSources;
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
        null,
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
    Pointer<NDIlib_find_create_t> pCreateSettings = ffi.calloc.call<NDIlib_find_create_t>(1);
    pCreateSettings.ref.show_local_sources = 1;

    NDIlib_find_instance_t pNDIfind = _ndi.NDIlib_find_create2(pCreateSettings);

    // wait for 10s for new sources
    // if none detected send results to main thread
    if (!_ndi.NDIlib_find_wait_for_sources(pNDIfind, 10000)) {
      ffi.calloc.free(pCreateSettings);
      object.sendPort.send(<String, int>{
        "pSources": 0,
        "sourceCount": 0,
      });
      return;
    }
    // give the sdk more time in case there is more then one source.
    // otherwise would only find one source and return before other ones are detected
    sleep(const Duration(seconds: 2));

    // retrieve all found sources from the sdk
    final pSourceCount = ffi.calloc.call<Uint32>(1);
    final pSources = _ndi.NDIlib_find_get_current_sources(pNDIfind, pSourceCount);

    // send back results and pointer address to later free it
    object.sendPort.send(<String, int>{
      "pSources": pSources.address,
      "sourceCount": pSourceCount.value,
    });
    ffi.calloc.free(pCreateSettings);
    ffi.calloc.free(pSourceCount);
  }

  ReceivePort? _fReceivePort;
  Isolate? _fIsolate;
  SendPort? _fIsoSendport;

  /// Sends the a configuration of needed scopes to the video frame isolate
  ///
  /// The Isolate will then only render the specified scopes

  void updateScopeTypes(Set<ScopeTypes> types) {
    _fIsoSendport?.send(types);
  }

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
    Function(
      double frameRate,
      Duration renderDelay,
      ui.Size frameSize,
    )
        onFrame,
    Rect mask,
    bool maskActive,
    Set<ScopeTypes> scopeTypes,
    bool accurateRendering,
  ) async {
    final completer = Completer();
    _fReceivePort = ReceivePort();

    // create the listener before starting the isolate to prevent missing the first messages

    _fReceivePort!.listen(
      (data) {
        listenCallback(data, onFrame);
      },
      onDone: () {
        // complete the future once the Isolate has returned and receiving has stopped
        completer.complete();
      },
    );

    // create the isolate that continously receives NDI frames and finishes once stopGetFrames() is called
    _fIsolate = await Isolate.spawn(
      _getFrames,
      _FMObject(
        source.address,
        _pRecv.address,
        _fReceivePort!.sendPort,
        mask,
        maskActive,
        scopeTypes,
        accurateRendering,
      ),
      debugName: "Video Frame Isolate",
    );
    // return intermediate future until receiving has ended
    return completer.future;
  }

  void listenCallback(
    dynamic data,
    Function(
      double frameRate,
      Duration renderDelay,
      ui.Size frameSize,
    )
        onFrame,
  ) {
    if (data is Map<String, num>) {
      // check for data integrity and retreive pointers to frames from their addresses
      if (data["pRGBA"] != null &&
          data["width"] != null &&
          data["height"] != null &&
          data["pWF"] != null &&
          data["pWFRgb"] != null &&
          data["pWFParade"] != null &&
          data["pVScope"] != null &&
          data["pFalseC"] != null &&
          data["pYUVParade"] != null) {
        _fIsoSendport?.send("pause");

        Pointer<Uint8> pRGBA = Pointer.fromAddress(data["pRGBA"]! as int);
        Pointer<Uint8> pWF = Pointer.fromAddress(data["pWF"]! as int);
        Pointer<Uint8> pWFRgb = Pointer.fromAddress(data["pWFRgb"]! as int);
        Pointer<Uint8> pWFParade = Pointer.fromAddress(data["pWFParade"]! as int);
        Pointer<Uint8> pYUVParade = Pointer.fromAddress(data["pYUVParade"]! as int);
        Pointer<Uint8> pBlacklevel = Pointer.fromAddress(data["pBlacklevel"]! as int);
        Pointer<Uint8> pVscope = Pointer.fromAddress(data["pVScope"]! as int);
        Pointer<Uint8> pFalseC = Pointer.fromAddress(data["pFalseC"]! as int);

        int width = data["width"]! as int;
        int height = data["height"]! as int;

        double frameRate = (data["frameRate"] ?? 0) as double;
        int renderStartTime = (data["renderStartTime"] ?? 0) as int;

        // convert every pointer to a Uint8List and convert that with width and height to a ui.Image
        // then free the pointers immediatly

        if (pRGBA != nullptr) tr.update(TextureIDs.texRGBA, pRGBA, width, height);
        if (pFalseC != nullptr) tr.update(TextureIDs.texFalseC, pFalseC, width, height);
        if (pWF != nullptr) tr.update(TextureIDs.texWF, pWF, ScopeSize.width, ScopeSize.height);
        if (pWFRgb != nullptr) tr.update(TextureIDs.texWFRgb, pWFRgb, ScopeSize.width, ScopeSize.height);
        if (pWFParade != nullptr) tr.update(TextureIDs.texWFParade, pWFParade, ScopeSize.width, ScopeSize.height);
        if (pYUVParade != nullptr) tr.update(TextureIDs.texYUVParade, pYUVParade, ScopeSize.width, ScopeSize.height);
        if (pBlacklevel != nullptr) tr.update(TextureIDs.texBL, pBlacklevel, ScopeSize.width, ScopeSize.height);
        if (pVscope != nullptr) tr.update(TextureIDs.texVscope, pVscope, ScopeSize.height, ScopeSize.height);

        onFrame(
          frameRate,
          DateTime.now().difference(
            DateTime.fromMicrosecondsSinceEpoch(renderStartTime),
          ),
          ui.Size(width.toDouble(), height.toDouble()),
        );
        _fIsoSendport?.send("resume");
      }
    }
    // if the isolate send us its sendport for bidirectional communication store its reference
    // used for updating the mask inside the receiver thread
    if (data is SendPort) {
      _fIsoSendport = data;
      _printNDI("Stated Video Isolate");
    }
    if (data is String) {
      if (data == "ended") _killFrameIsolate();
    }
  }

  /// stops the receiving thread and closes communication
  Future<void> stopGetFrames() async {
    _fIsoSendport?.send("end");
    await Future.delayed(const Duration(milliseconds: 500));
    _killFrameIsolate();
  }

  _killFrameIsolate() {
    _fReceivePort?.close();
    _fIsolate?.kill(priority: Isolate.immediate);
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
    bool end = false;
    bool pause = false;
    bool accurateRendering = object.accurateRendering;
    Set<ScopeTypes> scopeTypes = object.scopeTypes;
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
        if (message is String) {
          if (message == "end") end = true;
          if (message == "pause") pause = true;
          if (message == "resume") pause = false;
        }
        if (message is Set<ScopeTypes>) {
          scopeTypes = message;
        }
      },
      onDone: () {},
    );

    // create the receiver instance
    //NDIlib_recv_instance_t pNDIrecv = _ndi.NDIlib_recv_create_v3(nullptr);
    NDIlib_recv_instance_t pNDIrecv = Pointer.fromAddress(object.pRecvA);
    //final pNDIRecv = Pointer.fromAddress(object.pRecvA).cast<NDIlib_recv_instance_t>();
    // get pointer of the desired source to receive from its address
    Pointer<NDIlib_source_t> pSource = Pointer.fromAddress(object.pSourceA);
    // connect to the source
    _ndi.NDIlib_recv_connect(pNDIrecv, pSource);
    // allocate the NDI video frame
    Pointer<NDIlib_video_frame_v2_t> pVideoFrame = ffi.calloc<NDIlib_video_frame_v2_t>();

    // initialize variables that are reused each loop
    int width = 0;
    int height = 0;
    // stores the type of the incoming frame -> NDIlib_frame_type_e
    int frame = -1;

    double frameRate = 0;
    int renderStartTime = 0;

    // receive until thread is killed
    while (!end) {
      // give the async listener time to process incoming messages from main thread by interrupting the synchronous code
      await Future.delayed(Duration.zero);

      if (pause) continue;
      // get the frame type -> NDIlib_frame_type_e
      frame = _ndi.NDIlib_recv_capture_v3(pNDIrecv, pVideoFrame, nullptr, nullptr, 200);
      // ignore the frame if it is not a video frame
      if (frame != NDIlib_frame_type_e.NDIlib_frame_type_video) continue;
      renderStartTime = DateTime.now().microsecondsSinceEpoch;
      width = pVideoFrame.ref.xres;
      height = pVideoFrame.ref.yres;
      frameRate = pVideoFrame.ref.frame_rate_N / pVideoFrame.ref.frame_rate_D;
      // allocate memory for the rgba frame and all the scopes/waveforms
      Pointer<Uint8> pRGBA = ffi.calloc.call<Uint8>(width * height * 4);
      Pointer<Uint8> pFalseC = ffi.calloc.call<Uint8>(width * height * 4);

      Pointer<Uint8> pWF = scopeTypes.contains(ScopeTypes.luma)
          ? ffi.calloc.call<Uint8>(ScopeSize.width * ScopeSize.height * 4)
          : nullptr;
      Pointer<Uint8> pWFRgb = scopeTypes.contains(ScopeTypes.rgb)
          ? ffi.calloc.call<Uint8>(ScopeSize.width * ScopeSize.height * 4)
          : nullptr;
      Pointer<Uint8> pWFParade = scopeTypes.contains(ScopeTypes.parade)
          ? ffi.calloc.call<Uint8>(ScopeSize.width * ScopeSize.height * 4)
          : nullptr;
      Pointer<Uint8> pYUVParade = scopeTypes.contains(ScopeTypes.yuvparade)
          ? ffi.calloc.call<Uint8>(ScopeSize.width * ScopeSize.height * 4)
          : nullptr;

      Pointer<Uint8> pBlacklevel = scopeTypes.contains(ScopeTypes.blacklevel)
          ? ffi.calloc.call<Uint8>(ScopeSize.width * ScopeSize.height * 4)
          : nullptr;

      Pointer<Uint8> pVScope = ffi.calloc.call<Uint8>(ScopeSize.height * ScopeSize.height * 4);
      // convert to rgba pointers based on the format
      switch (pVideoFrame.ref.FourCC) {
        case NDIlib_FourCC_video_type_e.NDIlib_FourCC_type_UYVY:
          // apply mask if active to source to reflect it on all scopes
          if (maskActive) {
            //! replace with CPU/GPU compatible
            scopes.rectMaskFrame(ui.Size(width.toDouble(), height.toDouble()), mask, pVideoFrame.ref.p_data, 1);
          }
          //! replace with CPU/GPU compatible
          scopes.renderScopes(
            width,
            height,
            pVideoFrame.ref.p_data,
            pRGBA,
            pWF,
            pWFRgb,
            pWFParade,
            pVScope,
            pFalseC,
            pYUVParade,
            pBlacklevel,
            ScopeInputFrameTypeE.uyvy,
            accurateRendering,
          );

          break;
        case NDIlib_FourCC_video_type_e.NDIlib_FourCC_type_BGRA:
          // apply mask if active to source to reflect it on all scopes
          if (maskActive) {
            //! replace with CPU/GPU compatible
            scopes.rectMaskFrame(ui.Size(width.toDouble(), height.toDouble()), mask, pVideoFrame.ref.p_data, 2);
          }

          scopes.renderScopes(
            width,
            height,
            pVideoFrame.ref.p_data,
            pRGBA,
            pWF,
            pWFRgb,
            pWFParade,
            pVScope,
            pFalseC,
            pYUVParade,
            pBlacklevel,
            ScopeInputFrameTypeE.bgra,
            accurateRendering,
          );

          //! replace with CPU/GPU compatible

          break;
        default:
          _printNDI("unsupported format");
      }
      // free the source pointer!!!
      _ndi.NDIlib_recv_free_video_v2(pNDIrecv, pVideoFrame);

      // send results back to main thread that will free the rgba pointers

      object.sendPort.send(<String, num>{
        "width": width,
        "height": height,
        "pRGBA": pRGBA.address,
        "pWF": pWF.address,
        "pWFRgb": pWFRgb.address,
        "pWFParade": pWFParade.address,
        "pVScope": pVScope.address,
        "pFalseC": pFalseC.address,
        "pYUVParade": pYUVParade.address,
        "pBlacklevel": pBlacklevel.address,
        "frameRate": frameRate,
        "renderStartTime": renderStartTime,
      });

      //receive next frame
    }

    _printNDI("Ended Video Isolate");
    object.sendPort.send("ended");
  }

  ReceivePort? _sfReceivePort;

  /// the same as getFrames but doesn't loop so only returns one frame as SavedInputFrame to be stored in a file
  Future<void> getSingleFrame(
    Pointer<NDIlib_source_t> pSource,
    Function(SavedInputFrame frame) onFrameReady,
    Rect mask,
    bool maskActive,
    Set<ScopeTypes> scopes,
  ) async {
    final completer = Completer();
    _sfReceivePort = ReceivePort();
    await Isolate.spawn(
      _getSingleFrame,
      _FMObject(pSource.address, _pRecv.address, _sfReceivePort!.sendPort, mask, maskActive, scopes, true),
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
            SavedInputFrame(bytes: bytes, width: width, height: height, format: format, timestamp: DateTime.now()),
          );
        }
      }
    });
    return completer.future;
  }

  static void _getSingleFrame(_FMObject object) {
    NDIlib_recv_instance_t pNDIrecv = Pointer.fromAddress(object.pRecvA);

    Pointer<NDIlib_video_frame_v2_t> pVideoFrame = ffi.calloc<NDIlib_video_frame_v2_t>();

    int width = 0;
    int height = 0;

    int frame = -1;
    int i = 0;
    NDIInputFormat format = NDIInputFormat.uyvy;

    while (frame != NDIlib_frame_type_e.NDIlib_frame_type_video && i < 5) {
      i++;
      frame = _ndi.NDIlib_recv_capture_v3(pNDIrecv, pVideoFrame, nullptr, nullptr, 1000);

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
          _printNDI("unsupported format");
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
  SendPort? _aSendport;

  Future<void> getAudio(
    Pointer<NDIlib_source_t> source,
    Function(NDIAudioLevelFrame level) onLevel,
    bool outputEnabled,
    String audioDeviceName,
  ) async {
    final completer = Completer();

    _aReceiveport = ReceivePort();

    _aReceiveport!.listen((data) {
      if (data is NDIAudioLevelFrame) {
        onLevel(data);
      }
      if (data is SendPort) {
        _aSendport = data;
        _printNDI("Started Audio Isolate");
      }
      if (data is String) {
        if (data == "ended") _killAudioIsolate();
      }
    }, onDone: (() {
      completer.complete();
    }));

    _aIsolate = await Isolate.spawn(
      _getAudio,
      _AMObject(
        _aReceiveport!.sendPort,
        source.address,
        _pRecv.address,
        outputEnabled,
        audioDeviceName,
      ),
    );

    return completer.future;
  }

  Future<void> stopGetAudio() async {
    _aSendport?.send("end");
    await Future.delayed(const Duration(milliseconds: 1000));
    _killAudioIsolate();
  }

  void _killAudioIsolate() {
    _aReceiveport?.close();
    _aIsolate?.kill(priority: Isolate.immediate);
    _aIsolate = null;
    _aReceiveport = null;
  }

  static void _getAudio(_AMObject object) async {
    bool end = false;
    // create audio player instance
    AudioPlayer player = AudioPlayer();

    // create message channel from main thread to this isolate
    ReceivePort rP = ReceivePort();

    bool outputEnabled = object.outputEnabled;
    String audioDeviceName = object.audioDeviceName;
    // listen for messages from main thread
    rP.listen((message) {
      if (message is bool) {
        outputEnabled = message;
      }
      if (message is String) {
        if (message == "end") end = true;
      }
      if (message is Map<String, String>) {
        if (message["name"] != null) audioDeviceName = message["name"] ?? "";
      }
    });

    object.sendPort.send(rP.sendPort);

    NDIlib_recv_instance_t pNDIrecv = Pointer.fromAddress(object.pRecvA);
    //final pNDIRecv = Pointer.fromAddress(object.pRecvA).cast<NDIlib_recv_instance_t>();
    // get pointer of the desired source to receive from its address
    //Pointer<NDIlib_source_t> pSource = Pointer.fromAddress(object.pSourceA);
    // connect to the source
    //! no need since already connected by video frame isolate
    //_ndi.NDIlib_recv_connect(pNDIrecv, pSource);

    Pointer<NDIlib_audio_frame_v2_t> pAudioFrame = ffi.calloc<NDIlib_audio_frame_v2_t>();

    int frame = -1;

    player.openDriverByName(audioDeviceName);

    while (!end) {
      // async break to listen for receivport messages
      await Future.delayed(Duration.zero);
      // get frame typr
      frame = _ndi.NDIlib_recv_capture_v2(pNDIrecv, nullptr, pAudioFrame, nullptr, 1000);
      // if frame is not audio return
      if (frame != NDIlib_frame_type_e.NDIlib_frame_type_audio) continue;
      // get audio frame info
      int channels = pAudioFrame.ref.no_channels;
      int samples = pAudioFrame.ref.no_samples;
      int stride = pAudioFrame.ref.channel_stride_in_bytes;
      int rate = pAudioFrame.ref.sample_rate;
      // update player based on new info (only updates if info is different to last)
      player.updateDriverWithName(channels, rate, 16, audioDeviceName);
      // get the pointer to the 32 Float audio
      Pointer<Float> data = pAudioFrame.ref.p_data;

      if (outputEnabled) {
        // create pointer for 16Bit PCM Audio data
        Pointer<NDIlib_audio_frame_interleaved_16s_t> p16AudioFrame =
            ffi.calloc.call<NDIlib_audio_frame_interleaved_16s_t>();
        p16AudioFrame.ref.reference_level = 0;
        p16AudioFrame.ref.p_data = ffi.calloc.call<Int16>(samples * channels);

        // convert 32 Bit Audio to 16Bit audio
        _ndi.NDIlib_util_audio_to_interleaved_16s_v2(pAudioFrame, p16AudioFrame);

        // create Uint8List from pointer to 16Bit audio
        int bufferSize = 2 * channels * samples;
        Pointer<Int16> pData = p16AudioFrame.ref.p_data;
        Uint8List buffer = pData.cast<Uint8>().asTypedList(bufferSize);

        // play the buffer
        player.play(buffer);

        // free the generated 16Bit audio
        ffi.calloc.free(pData);
        ffi.calloc.free(p16AudioFrame);
      }

      // send audio levels to UI
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
      // free the received 32 Bit audio frame
      _ndi.NDIlib_recv_free_audio_v2(pNDIrecv, pAudioFrame);
    }
    player.dispose();
    _printNDI("Ended Audio Isolate");
    object.sendPort.send("ended");
  }

  /// Update the Audio Isolate with new value(s)
  ///
  /// set [outputEnabled] to true if you want to play the audio
  void updateAudioEnabled(bool outputEnabled) {
    if (_aSendport == null) return;
    _aSendport!.send(outputEnabled);
  }

  void updateAudioDevice(String name) {
    if (_aSendport == null) return;
    _aSendport!.send(<String, String>{"name": name});
  }

  /// Deinitializes the NDI Library
  ///
  /// Disconnects from any source
  /// Frees memory if necessary
  Future<void> dispose() async {
    // stop all isolates
    await Future.wait([stopGetFrames(), stopGetAudio()]);

    // disconnect from any sources
    _ndi.NDIlib_recv_connect(_pRecv, nullptr);
    // destroy recv instance
    _ndi.NDIlib_recv_destroy(_pRecv);
    // free sources pointer
    if (_pSources != null && _pSources != nullptr) ffi.calloc.free(_pSources!);
    _ndi.NDIlib_destroy();
    _printNDI("Library successfully disposed");
  }
}

class _AMObject {
  SendPort sendPort;
  int pRecvA;
  int pSourceA;
  bool outputEnabled;
  String audioDeviceName;
  _AMObject(
    this.sendPort,
    this.pSourceA,
    this.pRecvA,
    this.outputEnabled,
    this.audioDeviceName,
  );
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
  Rect mask;
  bool maskActive;
  Set<ScopeTypes> scopeTypes;
  bool accurateRendering;
  _FMObject(
    this.pSourceA,
    this.pRecvA,
    this.sendPort,
    this.mask,
    this.maskActive,
    this.scopeTypes,
    this.accurateRendering,
  );
}

class NDIAudioLevelFrame {
  List<double> channelLevels;

  NDIAudioLevelFrame({required this.channelLevels});
}

void _printNDI(String m) {
  if (kDebugMode) {
    print("$_ndiLabel [\x1B[32m${DateTime.now().toTimeString()}\x1B[0m] $m");
  }
}

const String _ndiLabel = "[\x1B[34;1mNDI\x1B[0m]";
