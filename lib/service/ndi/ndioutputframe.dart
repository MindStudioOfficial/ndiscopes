import 'dart:ffi' as ffi;
import 'dart:ui' as ui;

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

class NDIPointerOutputFrame {
  PointerImage iRGBA;
  PointerImage iWF;
  PointerImage iWFRgb;
  PointerImage iWFParade;
  PointerImage iVScope;
  PointerImage iFalseC;

  NDIPointerOutputFrame({
    required this.iRGBA,
    required this.iWF,
    required this.iWFRgb,
    required this.iWFParade,
    required this.iVScope,
    required this.iFalseC,
  });
}

class PointerImage {
  ffi.Pointer<ffi.Uint8> data;
  ui.Size size;
  PointerImage({required this.data, required this.size});
}
