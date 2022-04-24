import 'dart:ffi';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ndiscopes/config.dart';
import 'package:ndiscopes/models/buttonstyles.dart';
import 'package:ndiscopes/models/colors.dart';
import 'package:ndiscopes/models/textstyles.dart';
import 'package:ndiscopes/providers/frameprovider.dart';
import 'package:ndiscopes/providers/maskprovider.dart';
import 'package:ndiscopes/providers/scopesettingsprovider.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'package:ndiscopes/service/settings.dart';
import 'package:ndiscopes/util/saveloadframe.dart';
import 'package:ndiscopes/widgets/framebrowser.dart';
import 'package:ndiscopes/widgets/player.dart';
import 'package:ndiscopes/widgets/scopes.dart';
import 'package:ndiscopes/widgets/settings.dart';
import 'package:ndiscopes/widgets/window.dart';
import 'package:provider/provider.dart';

late NDI ndi;

void main() {
  Paint.enableDithering = true;
  ndi = NDI();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => Frame(),
        ),
        ChangeNotifierProvider(
          create: (_) => MaskProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ScopeSettings(),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(unselectedWidgetColor: cHighlight, toggleableActiveColor: cHighlight),
        scrollBehavior:
            const MaterialScrollBehavior().copyWith(dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch}),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: cAppBackground,
          body: const Main(),
        ),
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
  NDISource? selectedSource;
  bool refOpen = false;
  bool settingsOpen = false;
  bool portraitLayout = false;
  @override
  void initState() {
    super.initState();
    checkGPU();
    loadSettings();
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

  loadSettings() {
    loadScopeSettings().then((s) {
      context.read<ScopeSettings>().update(s);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      double aspect = constraints.maxWidth / constraints.maxHeight;
      portraitLayout = aspect < 1.3;
      int scopesCountX = portraitLayout ? 2 : 3;
      double width = constraints.maxWidth - scopesCountX * 2;
      return Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          WindowTitleBar(
            sourceName: selectedSource?.name ?? "No Source",
          ),
          //* top part
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Flexible(
                  flex: 2,
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: RepaintBoundary(
                          child: FrameViewer(
                            onSaveFrame: () {
                              if (selectedSource == null) return;
                              ndi.getSingleFrame(
                                selectedSource!.source,
                                const Size(580, 256),
                                (frame) {
                                  saveInputFrame(frame);
                                },
                                context.read<MaskProvider>().rect,
                                context.read<MaskProvider>().active,
                              );
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
                                    () => context.read<Frame>().updateImageFrame(frame),
                                  ),
                                  context.read<MaskProvider>().rect,
                                  context.read<MaskProvider>().active,
                                );
                              }
                            },
                            onToggleFrameBrowser: (open) {
                              setState(() {
                                refOpen = open;
                              });
                            },
                            onToggleSettings: (open) {
                              setState(() {
                                settingsOpen = open;
                              });
                            },
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: refOpen ? 175 : 0,
                        curve: Curves.easeInOutQuad,
                        child: const SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: NeverScrollableScrollPhysics(),
                          child: SizedBox(
                            width: 175,
                            child: FrameBrowserV2(),
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: settingsOpen ? 225 : 0,
                        curve: Curves.easeInOutQuad,
                        child: const SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: NeverScrollableScrollPhysics(),
                          child: SizedBox(
                            width: 225,
                            child: Settings(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!portraitLayout)
                  Flexible(
                    flex: 1,
                    child: Container(
                      color: Colors.black,
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          VerticalDivider(
                            width: 2,
                            thickness: 2,
                            color: cPrimary,
                            endIndent: 0,
                            indent: 0,
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              controller: ScrollController(),
                              child: const VscopeV2(
                                title: "UV Vectorscope",
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          //* bottom part
          Container(
            color: Colors.black,
            child: IntrinsicHeight(
              child: Wrap(
                //mainAxisSize: MainAxisSize.max,
                children: [
                  SizedBox(
                    width: width / scopesCountX,
                    child: ScopeV2(
                      title: "Luma Waveform",
                      img: context.watch<Frame>().imageFrame?.iWF,
                      ovl: context.watch<Frame>().overlayFrame?.iWF,
                      isParade: false,
                    ),
                  ),
                  SizedBox(
                    width: width / scopesCountX,
                    child: ScopeV2(
                      title: "RGB Waveform",
                      img: context.watch<Frame>().imageFrame?.iWFRgb,
                      ovl: context.watch<Frame>().overlayFrame?.iWFRgb,
                      isParade: false,
                    ),
                  ),
                  SizedBox(
                    width: width / scopesCountX,
                    child: ScopeV2(
                      title: "RGB Parade",
                      img: context.watch<Frame>().imageFrame?.iWFParade,
                      ovl: context.watch<Frame>().overlayFrame?.iWFParade,
                      isParade: true,
                    ),
                  ),
                  if (portraitLayout)
                    SizedBox(
                      width: width / scopesCountX / 2,
                      child: const VscopeV2(
                        title: "UV Vectorscope",
                      ),
                    )
                ],
              ),
            ),
          )
        ],
      );
    });
  }
}
