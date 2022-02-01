import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'package:ndiscopes/widgets/player.dart';

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
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.grey.shade900,
        body: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            FrameViewer(frame: currentFrame),
          ],
        ),
      ),
    );
  }
}
