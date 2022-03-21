import 'dart:ffi';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ndiscopes/config.dart';
import 'package:ndiscopes/models/buttonstyles.dart';
import 'package:ndiscopes/models/colors.dart';
import 'package:ndiscopes/models/textstyles.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'package:ndiscopes/util/saveloadframe.dart';
import 'package:ndiscopes/widgets/framebrowser.dart';
import 'package:ndiscopes/widgets/player.dart';
import 'package:ndiscopes/widgets/scopes.dart';
import 'package:ndiscopes/widgets/window.dart';

late NDI ndi;
final appConfig = AppConfig();

void main() {
  ndi = NDI();
  runApp(
    MaterialApp(
      scrollBehavior:
          const MaterialScrollBehavior().copyWith(dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch}),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: cAppBackground,
        body: const Main(),
      ),
    ),
  );

  doWhenWindowReady(() {
    const initialSize = Size(1280, 720);
    appWindow.title = "NDIScopes";
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
  NDIOutputFrame? currentFrame;
  NDIOutputFrame? overlayFrame;
  double overlayOpacity = .5;
  NDISource? selectedSource;

  OverlayMode overlayMode = OverlayMode.splitVertical;
  double splitPos = 0.5;
  bool flipSplit = false;

  Rect mask = Rect.zero;
  bool maskActive = false;

  @override
  void initState() {
    super.initState();
    checkGPU();
  }

  void checkGPU() {
    final major = calloc<Int32>();
    final minor = calloc<Int32>();
    pixconvertCUDA.getDeviceProperties(major, minor);
    // ignore: avoid_print
    print("GPU version ${major.value}.${minor.value}");
    if (major.value == 0) {
      Future.delayed(const Duration(seconds: 1), () {
        showDialog(
          context: context,
          builder: (context) {
            return SimpleDialog(
              backgroundColor: cDialogBackground,
              elevation: 0,
              title: Text(
                "Failed to check GPU version.",
                style: tDefault,
              ),
              children: [
                TextButton(
                  style: bTextDefault,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "OK",
                      style: tSmall,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      });
    } else if (major.value < appConfig.minMajorCC) {
      Future.delayed(const Duration(seconds: 1), () {
        showDialog(
          context: context,
          builder: (context) {
            return SimpleDialog(
              backgroundColor: cDialogBackground,
              elevation: 0,
              title: Text(
                "Your GPU might not be supported",
                style: tDefault,
              ),
              children: [
                TextButton(
                  style: bTextDefault,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "OK",
                      style: tSmall,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      });
    }
    calloc.free(major);
    calloc.free(minor);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          WindowTitleBar(sourceName: selectedSource != null ? selectedSource!.name : "No Source"),
          Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: SizedBox(
                  height: constraints.maxHeight - appWindow.titleBarHeight - 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: FrameViewer(
                          onMaskUpdate: (m, active) {
                            maskActive = active;
                            mask = m;
                            ndi.updateMask(mask, maskActive);
                            setState(() {});
                          },
                          frame: currentFrame,
                          overlay: overlayFrame,
                          overlayOpacity: overlayOpacity,
                          onSaveFrame: () {
                            if (selectedSource == null) return;
                            ndi.getSingleFrame(
                              selectedSource!.source,
                              const Size(580, 256),
                              (frame) {
                                saveInputFrame(frame);
                              },
                              mask,
                              maskActive,
                            );
                          },
                          onRemoveOverlay: () {
                            overlayFrame = null;
                            setState(() {});
                          },
                          onSelectSource: (index) {
                            final pS = ndi.getSourceAt(index);

                            if (pS != null) {
                              ndi.stopGetFrames();
                              selectedSource = NDISource(pS);
                              setState(() {});
                              ndi.getFrames(
                                selectedSource!.source,
                                const Size(580, 256),
                                (frame) => setState(
                                  () => currentFrame = frame,
                                ),
                                mask,
                                maskActive,
                              );
                            }
                          },
                          onOverlayChanged: (mode, pos, flip) {
                            setState(() {
                              overlayMode = mode;
                              splitPos = pos;
                              flipSplit = flip;
                            });
                          },
                        ),
                      ),
                      SizedBox(
                        height: 150,
                        child: Framebrowser(
                          onselectFrame: (frame) {
                            overlayFrame = frame;
                            setState(() {});
                          },
                        ),
                      ),
                      Container(
                        height: 150,
                        color: Colors.transparent,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                color: cAppBackground,
                height: constraints.maxHeight - appWindow.titleBarHeight - 2,
                width: 600,
                child: Scopes(
                  frame: currentFrame,
                  overlay: overlayFrame,
                  overlayMode: overlayMode,
                  splitPos: splitPos,
                  flipSplit: flipSplit,
                ),
              ),
            ],
          ),
        ],
      );
    });
  }
}
