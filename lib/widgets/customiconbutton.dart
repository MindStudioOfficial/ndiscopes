import 'package:flutter/material.dart';
import 'package:ndiscopes/models/models.dart';
import 'package:ndiscopes/widgets/customtooltip.dart';

class CustomIconButton extends StatefulWidget {
  final String tooltip;
  final void Function() onPressed;
  final IconData iconData;
  final bool? active;
  final LogicalKeySet? shortcutKeys;
  final bool? loading;
  const CustomIconButton({
    Key? key,
    required this.tooltip,
    required this.onPressed,
    required this.iconData,
    this.active,
    this.shortcutKeys,
    this.loading,
  }) : super(key: key);

  @override
  State<CustomIconButton> createState() => _CustomIconButtonState();
}

class _CustomIconButtonState extends State<CustomIconButton> {
  @override
  Widget build(BuildContext context) {
    return DelayedCustomTooltip(
      widget.tooltip,
      shortcutKeys: widget.shortcutKeys,
      child: widget.loading == true
          ? const SizedBox(
              width: 45,
              height: 45,
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: CircularProgressIndicator(),
              ),
            )
          : TextButton(
              style: bIconDefault,
              onPressed: widget.onPressed,
              child: Icon(
                widget.iconData,
                size: 25,
                color: widget.active == true ? Colors.blue : Colors.white,
              ),
            ),
    );
  }
}
