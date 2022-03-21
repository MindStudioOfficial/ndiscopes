import 'package:flutter/material.dart';
import 'package:ndiscopes/models/colors.dart';

BoxDecoration dBorder = BoxDecoration(
  borderRadius: BorderRadius.zero,
  border: Border.all(color: cDecorationBorder, width: 1),
);

BoxDecoration dGradient = BoxDecoration(
  gradient: LinearGradient(
    colors: [cPrimary, cDominant],
    //stops: [0.8, 1],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  ),
);

BoxDecoration dHoverGradient = BoxDecoration(
  gradient: LinearGradient(
    colors: [cPrimary, cPrimary],
    //stops: [0.8, 1],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  ),
);

BoxDecoration dAccentGradient = BoxDecoration(
  gradient: RadialGradient(
    colors: [cAccent, cPrimary],
    radius: 1,
    center: Alignment.bottomRight,
  ),
);
