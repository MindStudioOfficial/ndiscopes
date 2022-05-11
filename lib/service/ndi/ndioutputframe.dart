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
