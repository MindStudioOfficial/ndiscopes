import 'dart:ffi' as ffi;
import 'package:flutter/material.dart';

class ScopesFFI {
  final ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName) _lookup;

  /// The symbols are looked up in [dynamicLibrary].
  ScopesFFI(ffi.DynamicLibrary dynamicLibrary) : _lookup = dynamicLibrary.lookup;

  /// The symbols are looked up with [lookup].
  ScopesFFI.fromLookup(ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName) lookup) : _lookup = lookup;

  // ====================
  // *RENDER SCOPES
  // ====================

  /// Converts the [src] image to rgba based on the specified [inputType]
  ///
  double renderScopes(
    int srcWidth,
    int srcHeight,
    ffi.Pointer<ffi.Uint8> src,
    ffi.Pointer<ffi.Uint8> rgba,
    ffi.Pointer<ffi.Uint8> wf,
    ffi.Pointer<ffi.Uint8> wfRgb,
    ffi.Pointer<ffi.Uint8> wfParade,
    ffi.Pointer<ffi.Uint8> vScope,
    ffi.Pointer<ffi.Uint8> falseC,
    ffi.Pointer<ffi.Uint8> yuvParade,
    ffi.Pointer<ffi.Uint8> blacklevel,
    int inputType,
  ) {
    return _renderScopes(
      srcWidth,
      srcHeight,
      src,
      rgba,
      wf,
      wfRgb,
      wfParade,
      vScope,
      falseC,
      yuvParade,
      blacklevel,
      inputType,
    );
  }

  late final _renderScopesPtr = _lookup<
      ffi.NativeFunction<
          ffi.Float Function(
    ffi.Int32,
    ffi.Int32,
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Uint8>,
    ffi.Int32,
  )>>("renderScopes");

  late final _renderScopes = _renderScopesPtr.asFunction<
      double Function(
    int,
    int,
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Uint8>,
    int,
  )>();

  // ====================
  // *Get Device Properties
  // ====================

  void getDeviceProperties(
    ffi.Pointer<ffi.Int32> major,
    ffi.Pointer<ffi.Int32> minor,
  ) {
    return _getDeviceProperties(major, minor);
  }

  late final _getDevicePropertiesPtr = _lookup<
      ffi.NativeFunction<
          ffi.Void Function(
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Int32>,
  )>>("getDeviceProperties");

  late final _getDeviceProperties = _getDevicePropertiesPtr.asFunction<
      void Function(
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Int32>,
  )>();

  // ====================
  // *Rect Mask Frame
  // ====================

  /// format: 1 = UYVY | 2 = BGRA
  void rectMaskFrame(Size frameSize, Rect mask, ffi.Pointer<ffi.Uint8> frame, int format) {
    return _rectMaskFrame(
      frameSize.width.toInt(),
      frameSize.height.toInt(),
      mask.left.toInt(),
      mask.top.toInt(),
      mask.width.toInt(),
      mask.height.toInt(),
      frame,
      format,
    );
  }

  late final _rectMaskFramePtr = _lookup<
      ffi.NativeFunction<
          ffi.Void Function(
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Pointer<ffi.Uint8>,
    ffi.Int32,
  )>>("rectMaskFrame");

  late final _rectMaskFrame = _rectMaskFramePtr.asFunction<
      void Function(
    int fWidth,
    int fHeight,
    int mLeft,
    int mTop,
    int mWidth,
    int mHeight,
    ffi.Pointer<ffi.Uint8> frame,
    int format,
  )>();

  // ====================
  // *Thumbnail from uyvy
  // ====================

  void thumbnailFromUyvy(
    ffi.Pointer<ffi.Uint8> src,
    int srcWidth,
    int srcHeight,
    ffi.Pointer<ffi.Uint8> tn,
    int tnWidth,
    int tnHeight,
  ) {
    return _thumbnailFromUyvy(src, srcWidth, srcHeight, tn, tnWidth, tnHeight);
  }

  late final _thumbnailFromUyvyPtr = _lookup<
      ffi.NativeFunction<
          ffi.Void Function(
    ffi.Pointer<ffi.Uint8>,
    ffi.Int32,
    ffi.Int32,
    ffi.Pointer<ffi.Uint8>,
    ffi.Int32,
    ffi.Int32,
  )>>("thumbnailFromUyvy");

  late final _thumbnailFromUyvy = _thumbnailFromUyvyPtr.asFunction<
      void Function(
    ffi.Pointer<ffi.Uint8> src,
    int srcWidth,
    int srcHeight,
    ffi.Pointer<ffi.Uint8> tn,
    int tnWidth,
    int tnHeight,
  )>();

  // ====================
  // *Thumbnail from bgra
  // ====================

  void thumbnailFromBgra(
    ffi.Pointer<ffi.Uint8> src,
    int srcWidth,
    int srcHeight,
    ffi.Pointer<ffi.Uint8> tn,
    int tnWidth,
    int tnHeight,
  ) {
    return _thumbnailFromBgra(src, srcWidth, srcHeight, tn, tnWidth, tnHeight);
  }

  late final _thumbnailFromBgraPtr = _lookup<
      ffi.NativeFunction<
          ffi.Void Function(
    ffi.Pointer<ffi.Uint8>,
    ffi.Int32,
    ffi.Int32,
    ffi.Pointer<ffi.Uint8>,
    ffi.Int32,
    ffi.Int32,
  )>>("thumbnailFromBgra");

  late final _thumbnailFromBgra = _thumbnailFromBgraPtr.asFunction<
      void Function(
    ffi.Pointer<ffi.Uint8> src,
    int srcWidth,
    int srcHeight,
    ffi.Pointer<ffi.Uint8> tn,
    int tnWidth,
    int tnHeight,
  )>();
}

abstract class ScopeInputFrameTypeE {
  static const int uyvy = 0;
  static const int bgra = 1;
  static const int uyva = 2;
  static const int bgrx = 3;
}
