import 'package:flutter/material.dart';

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
