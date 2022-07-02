import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:ndiscopes/models/colors.dart';
import 'package:ndiscopes/providers/providers.dart';
import 'package:ndiscopes/widgets/versionchecker.dart';
import 'package:provider/provider.dart';

final bc = WindowButtonColors(
  iconNormal: Colors.white,
  iconMouseDown: Colors.white,
  iconMouseOver: Colors.grey,
  normal: Colors.transparent,
  mouseOver: Colors.black.withOpacity(0.4),
  mouseDown: Colors.black.withOpacity(0.8),
);

class WindowTitleBar extends StatelessWidget {
  final String sourceName;
  const WindowTitleBar({
    Key? key,
    required this.sourceName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<Statistics>();
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 32.0,
      color: cWindowTitleBar,
      child: MoveWindow(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    "NDI Scopes by MindStudio  -  $sourceName ${stats.frameSize.width.toString() + " x " + stats.frameSize.height.toString()} ${stats.renderFrameRate.clamp(0, stats.frameRate).toStringAsFixed(1)}/${stats.frameRate.toStringAsFixed(1)}fps ${(stats.renderDelay.inMicroseconds / 1000).toStringAsFixed(2)}ms",
                    style: TextStyle(color: Colors.white.withOpacity(.2)),
                    overflow: TextOverflow.visible,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
            const VersionChecker(),
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
