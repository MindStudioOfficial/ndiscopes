import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:ndiscopes/bindings/ndi_ffi_bindigs_v3.dart';

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
