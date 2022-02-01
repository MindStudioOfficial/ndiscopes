import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'package:ndiscopes/widgets/player.dart';
import 'package:ndiscopes/widgets/scopes.dart';
import 'package:ndiscopes/widgets/window.dart';

late NDI ndi;

void main() {
  ndi = NDI();
  runApp(const Main());

  doWhenWindowReady(() {
    const initialSize = Size(1280, 720);
    appWindow.size = initialSize;
    appWindow.show();
  });
}

class Main extends StatefulWidget {
  const Main({Key? key}) : super(key: key);

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> {
  NDIFrame? currentFrame;
  NDISource? selectedSource;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.grey.shade900,
        body: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            WindowTitleBar(sourceName: selectedSource != null ? selectedSource!.name : "No Source"),
            Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FrameViewer(
                    frame: currentFrame,
                    onSelectSource: (index) {
                      final pS = ndi.getSourceAt(index);

                      if (pS != null) {
                        ndi.stopGetFrames();
                        selectedSource = NDISource(pS);
                        setState(() {});
                        ndi.getFrames(selectedSource!.source, (frame) => setState(() => currentFrame = frame));
                      }
                    }),
                Scopes(frame: currentFrame),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
