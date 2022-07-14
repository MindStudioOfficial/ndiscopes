import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:ffi/ffi.dart' as ffi;
import 'package:ndiscopes/bindings/scopes_bindings_v1.dart';
import 'package:ndiscopes/providers/providers.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'package:ndiscopes/service/textures/textures.dart';

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
      ffi.Pointer<ffi.Uint8> pSrc = ffi.calloc.call<ffi.Uint8>(bytes.length);
      // copy source bytes into pointer
      pSrc.asTypedList(bytes.length).setAll(0, bytes);
      // allocate byte pointer with dimensions of the thumbnail for thumbnail frame (*4 for RGBA)
      ffi.Pointer<ffi.Uint8> pTn = ffi.calloc.call<ffi.Uint8>(160 * 90 * 4);
      // create thumbnail from source in CUDA
      //! replace with CPU/GPU compatible
      switch (format) {
        case NDIInputFormat.bgra:
          scopes.thumbnailFromBgra(pSrc, width, height, pTn, 160, 90);
          break;
        case NDIInputFormat.uyvy:
          scopes.thumbnailFromUyvy(pSrc, width, height, pTn, 160, 90);
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
          ffi.calloc.free(pSrc);
          ffi.calloc.free(pTn);
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
  Future<NDIOutputFrame?> convertToScopes(int scopeWidth, int scopeHeight) async {
    final c = Completer<NDIOutputFrame?>();

    // create all necessary pointers with desired dimesions *4 (4 Bytes RGBA)
    ffi.Pointer<ffi.Uint8> pSrc = ffi.calloc.call<ffi.Uint8>(bytes.length);
    ffi.Pointer<ffi.Uint8> pRGBA = ffi.calloc.call<ffi.Uint8>(width * height * 4);
    ffi.Pointer<ffi.Uint8> pWF = ffi.calloc.call<ffi.Uint8>(scopeWidth * scopeHeight * 4);
    ffi.Pointer<ffi.Uint8> pWFRgb = ffi.calloc.call<ffi.Uint8>(scopeWidth * scopeHeight * 4);
    ffi.Pointer<ffi.Uint8> pWFParade = ffi.calloc.call<ffi.Uint8>(scopeWidth * scopeHeight * 4);
    ffi.Pointer<ffi.Uint8> pVScope = ffi.calloc.call<ffi.Uint8>(scopeHeight * scopeHeight * 4);
    ffi.Pointer<ffi.Uint8> pFalseC = ffi.calloc.call<ffi.Uint8>(width * height * 4);

    // copy source bytes into pointer
    pSrc.asTypedList(bytes.length).setAll(0, bytes);

    // use different convert method based on input frame format
    switch (format) {
      case NDIInputFormat.uyvy:
        //! replace with CPU/GPU compatible
        scopes.renderScopes(
          width,
          height,
          pSrc,
          pRGBA,
          pWF,
          pWFRgb,
          pWFParade,
          pVScope,
          pFalseC,
          ffi.nullptr, // !
          ffi.nullptr, // !
          ScopeInputFrameTypeE.uyvy,
        );
        break;
      case NDIInputFormat.bgra:
        //! replace with CPU/GPU compatible
        scopes.renderScopes(
          width,
          height,
          pSrc,
          pRGBA,
          pWF,
          pWFRgb,
          pWFParade,
          pVScope,
          pFalseC,
          ffi.nullptr, // !
          ffi.nullptr, // !
          ScopeInputFrameTypeE.bgra,
        );
        break;
      default:
        c.complete(null);
        return c.future;
    }
    // convert from rgba bytes in pointers to ui.Image then free the pointers
    ui.decodeImageFromPixels(pRGBA.asTypedList(width * height * 4), width, height, ui.PixelFormat.rgba8888, (iRGBA) {
      ffi.calloc.free(pRGBA);
      ui.decodeImageFromPixels(
          pWF.asTypedList(scopeWidth * scopeHeight * 4), scopeWidth, scopeHeight, ui.PixelFormat.rgba8888, (iWF) {
        ffi.calloc.free(pWF);
        ui.decodeImageFromPixels(
            pWFRgb.asTypedList(scopeWidth * scopeHeight * 4), scopeWidth, scopeHeight, ui.PixelFormat.rgba8888,
            (iWFRgb) {
          ffi.calloc.free(pWFRgb);
          ui.decodeImageFromPixels(
              pWFParade.asTypedList(scopeWidth * scopeHeight * 4), scopeWidth, scopeHeight, ui.PixelFormat.rgba8888,
              (iWFParade) {
            ffi.calloc.free(pWFParade);
            ui.decodeImageFromPixels(
                pVScope.asTypedList(scopeHeight * scopeHeight * 4), scopeHeight, scopeHeight, ui.PixelFormat.rgba8888,
                (iVScope) {
              ffi.calloc.free(pVScope);
              // return the finished frames
              ui.decodeImageFromPixels(pFalseC.asTypedList(width * height * 4), width, height, ui.PixelFormat.rgba8888,
                  (iFalseC) {
                ffi.calloc.free(pFalseC);
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

  /// Renders all frames necessary to draw the source and all scopes/waveforms
  ///
  /// outputs everything as pointers instead of ui.Image
  ///
  /// provide desired width and height of the scopes
  ///
  Future<void> convertToScopesPointer() async {
    // create all necessary pointers with desired dimesions *4 (4 Bytes RGBA)
    ffi.Pointer<ffi.Uint8> pSrc = ffi.calloc.call<ffi.Uint8>(bytes.length);
    ffi.Pointer<ffi.Uint8> pRGBA = ffi.calloc.call<ffi.Uint8>(width * height * 4);
    ffi.Pointer<ffi.Uint8> pFalseC = ffi.calloc.call<ffi.Uint8>(width * height * 4);

    ffi.Pointer<ffi.Uint8> pWF = ffi.calloc.call<ffi.Uint8>(ScopeSize.width * ScopeSize.height * 4);
    ffi.Pointer<ffi.Uint8> pWFRgb = ffi.calloc.call<ffi.Uint8>(ScopeSize.width * ScopeSize.height * 4);
    ffi.Pointer<ffi.Uint8> pWFParade = ffi.calloc.call<ffi.Uint8>(ScopeSize.width * ScopeSize.height * 4);
    ffi.Pointer<ffi.Uint8> pYUVParade = ffi.calloc.call<ffi.Uint8>(ScopeSize.width * ScopeSize.height * 4);
    ffi.Pointer<ffi.Uint8> pHistogram = ffi.calloc.call<ffi.Uint8>(ScopeSize.width * ScopeSize.height * 4);

    ffi.Pointer<ffi.Uint8> pVScope = ffi.calloc.call<ffi.Uint8>(ScopeSize.height * ScopeSize.height * 4);

    // copy source bytes into pointer
    pSrc.asTypedList(bytes.length).setAll(0, bytes);

    // use different convert method based on input frame format
    switch (format) {
      case NDIInputFormat.uyvy:
        //! replace with CPU/GPU compatible
        scopes.renderScopes(
          width,
          height,
          pSrc,
          pRGBA,
          pWF,
          pWFRgb,
          pWFParade,
          pVScope,
          pFalseC,
          pYUVParade,
          pHistogram,
          ScopeInputFrameTypeE.uyvy,
        );
        break;
      case NDIInputFormat.bgra:
        //! replace with CPU/GPU compatible
        scopes.renderScopes(
          width,
          height,
          pSrc,
          pRGBA,
          pWF,
          pWFRgb,
          pWFParade,
          pVScope,
          pFalseC,
          pYUVParade,
          pHistogram,
          ScopeInputFrameTypeE.bgra,
        );
        break;
      default:
        return;
    }

    // update all textures
    tr.update(TextureIDs.texRGBAO, pRGBA, width, height);
    tr.update(TextureIDs.texFalseCO, pFalseC, width, height);

    tr.update(TextureIDs.texWFO, pWF, ScopeSize.width, ScopeSize.height);
    tr.update(TextureIDs.texWFRgbO, pWFRgb, ScopeSize.width, ScopeSize.height);
    tr.update(TextureIDs.texWFParadeO, pWFParade, ScopeSize.width, ScopeSize.height);
    tr.update(TextureIDs.texYUVParadeO, pYUVParade, ScopeSize.width, ScopeSize.height);
    tr.update(TextureIDs.texHistogramO, pHistogram, ScopeSize.height, ScopeSize.height);

    tr.update(TextureIDs.texVscopeO, pVScope, ScopeSize.height, ScopeSize.height);
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
