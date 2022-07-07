import 'package:texturerender/texturerender.dart';

late Texturerender tr;

const int texRGBA = 0;
const int texRGBAO = 1;
const int texFalseC = 2;
const int texFalseCO = 3;
const int texWF = 4;
const int texWFO = 5;
const int texWFRgb = 6;
const int texWFRgbO = 7;
const int texWFParade = 8;
const int texWFParadeO = 9;
const int texVscope = 10;
const int texVscopeO = 11;

Future<bool> initTextures() async {
  tr = Texturerender();
  bool succ = true;
  for (int i = 0; i < 12; i++) {
    if (!(await tr.register(i))) succ = false;
  }
  return succ;
}

Future<void> disposeTextures() async {
  await tr.dispose();
}
