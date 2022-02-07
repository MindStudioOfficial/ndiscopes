import 'package:flutter/material.dart';

Offset uvFromRGB(Color c) {
  double u = 128 + c.red * -.115 + c.green * -.385 + c.blue * .500;
  double v = 256 - (128 + c.red * .500 + c.green * -.454 + c.blue * -.046);
  return Offset(u, v);
}
