import 'package:flutter/material.dart';
import 'package:ndiscopes/models/colors.dart';

ButtonStyle bTextDefault = ButtonStyle(
  shape: MaterialStateProperty.all(
    const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
  ),
  backgroundColor: MaterialStateProperty.resolveWith(
    (states) {
      if (states.contains(MaterialState.hovered)) return const Color.fromRGBO(8, 8, 8, 1);
      return const Color.fromRGBO(24, 24, 24, 1);
    },
  ),
  overlayColor: MaterialStateProperty.all(Colors.transparent),
);

ButtonStyle bIconDefault = ButtonStyle(
  padding: MaterialStateProperty.all(EdgeInsets.zero),
  minimumSize: MaterialStateProperty.all(Size.zero),
  fixedSize: MaterialStateProperty.all(const Size(45, 45)),
  alignment: Alignment.center,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  shape: MaterialStateProperty.all(
    const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
  ),
  backgroundColor: MaterialStateProperty.resolveWith(
    (states) {
      if (states.contains(MaterialState.focused)) return cHighlight;
      if (states.contains(MaterialState.pressed)) return cHighlight;
      if (states.contains(MaterialState.hovered)) return const Color.fromRGBO(8, 8, 8, 1);
      return Colors.transparent;
    },
  ),
  overlayColor: MaterialStateProperty.all(Colors.transparent),
);
