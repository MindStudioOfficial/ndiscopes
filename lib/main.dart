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
    const initialSize = Size(1920, 1080);
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
        body: LayoutBuilder(builder: (context, constraints) {
          return Column(
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
                          ndi.getFrames(selectedSource!.source, const Size(580, 256),
                              (frame) => setState(() => currentFrame = frame));
                        }
                      }),
                  Container(
                    height: constraints.maxHeight - appWindow.titleBarHeight - 2,
                    color: Colors.black,
                    width: 600,
                    child: Scopes(frame: currentFrame),
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }
}
