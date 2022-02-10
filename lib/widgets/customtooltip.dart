import 'package:flutter/material.dart';
import 'package:ndiscopes/models/textstyles.dart';

Color toolTipBackgroundColor = const Color.fromRGBO(5, 5, 5, .7);

TextStyle toolTipTextStyle = tDefault.copyWith(
  fontSize: 14,
  color: Colors.white,
  fontWeight: FontWeight.bold,
);

BoxDecoration toolTipDecoration = BoxDecoration(
  borderRadius: BorderRadius.circular(0),
  color: toolTipBackgroundColor,
);

class CustomTooltip extends StatelessWidget {
  final String text;
  final Widget child;
  const CustomTooltip(
    this.text, {
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: text,
      child: child,
      textStyle: toolTipTextStyle,
      decoration: toolTipDecoration,
    );
  }
}

class DelayedCustomTooltip extends StatelessWidget {
  final String text;
  final Widget child;
  final Duration? delay;
  const DelayedCustomTooltip(
    this.text, {
    Key? key,
    required this.child,
    this.delay = const Duration(milliseconds: 333),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: text,
      child: child,
      textStyle: toolTipTextStyle,
      decoration: toolTipDecoration,
      waitDuration: delay,
    );
  }
}
