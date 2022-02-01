import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:ndiscopes/bindings/ndi_ffi_bindigs.dart';

NDIffi _ndi = NDIffi(DynamicLibrary.open("bin/Processing.NDI.Lib.x64.dll"));

class NDI {
  /// The class wrapping around the NDI FFI bindings.
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

  /// The List of [NDISource] containing available NDI sources.
  ///
  /// Update this by calling [await updateSources()].
  List<NDISource> sources = [];

  /// Asynchronously update the [ndi.sources] list of NDI sources.
  ///
  /// Access updated sources with [ndi.sources] after waiting for this future to complete.
  Future<void> updateSoures() async {
    Completer completer = Completer();
    ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(_updateSourcePointer, _SMObject(receivePort.sendPort));
    receivePort.listen(
      (data) {
        if (data is Map<String, int>) {
          if (data["pSources"] == null || data["sourceCount"] == null) return;
          int sourceCount = data["sourceCount"]!;
          _pSources = Pointer.fromAddress(data["pSources"]!).cast<NDIlib_source_t>();
          sources = [];
          for (int i = 0; i < sourceCount; i++) {
            sources.add(NDISource(_pSources![i]));
            completer.complete();
          }
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

    NDIlib_find_instance_t pNDIfind = _ndi.NDIlib_find_create2(pCreateSettings);
    if (!_ndi.NDIlib_find_wait_for_sources(pNDIfind, 5000)) {
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
}

class _SMObject {
  SendPort sendPort;
  _SMObject(this.sendPort);
}

/// A class wrapping around the internal [NDIlib_source_t] type.
///
/// Access a sources name with the [name] property.
class NDISource {
  NDIlib_source_t source;
  NDISource(this.source);

  /// Access the name of the given NDI source.
  String get name {
    return source.p_ndi_name.cast<Utf8>().toDartString();
  }

  @override
  String toString() {
    return name;
  }
}
