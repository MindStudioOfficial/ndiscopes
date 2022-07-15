import 'package:texturerender/texturerender.dart';

late Texturerender tr;

abstract class TextureIDs {
  static const int count = 18;
  static const int texRGBA = 0;
  static const int texRGBAO = 1;
  static const int texFalseC = 2;
  static const int texFalseCO = 3;
  static const int texWF = 4;
  static const int texWFO = 5;
  static const int texWFRgb = 6;
  static const int texWFRgbO = 7;
  static const int texWFParade = 8;
  static const int texWFParadeO = 9;
  static const int texVscope = 10;
  static const int texVscopeO = 11;
  static const int texYUVParade = 12;
  static const int texYUVParadeO = 13;
  static const int texHistogram = 14;
  static const int texHistogramO = 15;
  static const int texBL = 16;
  static const int texBLO = 17;
}

Future<bool> initTextures() async {
  tr = Texturerender();
  bool succ = true;
  for (int i = 0; i < TextureIDs.count; i++) {
    if (!(await tr.register(i))) succ = false;
  }
  return succ;
}

Future<void> disposeTextures() async {
  await tr.dispose();
}
