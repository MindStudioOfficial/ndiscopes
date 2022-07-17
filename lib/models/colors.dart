import 'package:flutter/material.dart';

Color cDominant = const Color.fromRGBO(14, 14, 14, 1);
Color cPrimary = const Color.fromRGBO(24, 24, 24, 1);
Color cAccent = const Color.fromARGB(255, 15, 29, 43);

Color cHighlight = const Color.fromARGB(255, 25, 120, 215);
Color cFocused = const Color.fromARGB(255, 0, 75, 149);

Color cWindowTitleBar = cDominant;
Color cAppBackground = cDominant;

Color cDialogBackground = cDominant.withOpacity(.8);
Color cSourceCard = cPrimary;
//Color cScopeBorder = cAccent;
Color cScopeTitleBackground = const Color.fromRGBO(22, 22, 22, 1);
Color cScopeTitleBackgroundHover = const Color.fromRGBO(16, 16, 16, 1);
Color cDecorationBorder = cPrimary;
Color cFrameBrowserHeader = cPrimary;
//Color cDirBackground = const Color.fromRGBO(22, 22, 22, 1);
//Color cDirHover = cPrimary;

Map<Color, String> falseColors = {
  const Color.fromRGBO(80, 39, 81, 1): "<2",
  const Color.fromRGBO(9, 101, 150, 1): "2 - 8",
  const Color.fromRGBO(18, 133, 152, 1): "8 - 15",
  const Color.fromRGBO(66, 163, 169, 1): "15 - 24",
  const Color.fromRGBO(133, 133, 133, 1): "24 - 43",
  const Color.fromRGBO(98, 185, 70, 1): "43 - 47",
  const Color.fromRGBO(159, 159, 159, 1): "47 - 54",
  const Color.fromRGBO(236, 181, 188, 1): "54 - 58",
  const Color.fromRGBO(209, 209, 209, 1): "58 - 77",
  const Color.fromRGBO(240, 231, 140, 1): "77 - 84",
  const Color.fromRGBO(255, 255, 1, 1): "84 - 93",
  const Color.fromRGBO(255, 139, 0, 1): "93 - 100",
  const Color.fromRGBO(255, 0, 0, 1): ">=100",
};
