import 'package:flutter/material.dart';
import 'package:ndiscopes/models/models.dart';

ThemeData thDefault = ThemeData(
  unselectedWidgetColor: cHighlight,
  toggleableActiveColor: cHighlight,
  checkboxTheme: CheckboxThemeData(
    fillColor: MaterialStateProperty.resolveWith(
      (states) {
        if (states.contains(MaterialState.focused)) return cFocused;
        if (states.contains(MaterialState.selected)) return cHighlight;
        return Colors.white;
      },
    ),
    checkColor: MaterialStateProperty.resolveWith(
      (states) {
        return Colors.white;
      },
    ),
  ),
  listTileTheme: ListTileThemeData(selectedTileColor: cFocused),
  highlightColor: cFocused,
  hoverColor: cHighlight,
  popupMenuTheme: const PopupMenuThemeData(elevation: 0, color: Colors.white),
);
