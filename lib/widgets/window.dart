import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

final bc = WindowButtonColors(
  iconNormal: Colors.white,
  iconMouseDown: Colors.white,
  iconMouseOver: Colors.grey,
  normal: Colors.transparent,
  mouseOver: Colors.black.withOpacity(0.4),
  mouseDown: Colors.black.withOpacity(0.8),
);

class WindowTitleBar extends StatelessWidget {
  const WindowTitleBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 32.0,
      color: Colors.transparent,
      child: MoveWindow(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(),
            ),
            MinimizeWindowButton(colors: bc),
            MaximizeWindowButton(colors: bc),
            CloseWindowButton(
              onPressed: () {
                appWindow.close();
              },
              colors: bc,
            ),
          ],
        ),
      ),
    );
  }
}
