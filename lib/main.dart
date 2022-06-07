import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:dart_discord_rpc/dart_discord_rpc.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ndiscopes/models/models.dart';
import 'package:ndiscopes/providers/providers.dart';
import 'package:ndiscopes/service/gfx/gfx.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'package:ndiscopes/service/settings.dart';
import 'package:ndiscopes/util/discordrpc.dart';
import 'package:ndiscopes/util/saveloadframe.dart';
import 'package:ndiscopes/widgets/widgets.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

late NDI ndi;

void main() {
  // initialize components
  init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Frame()),
        ChangeNotifierProvider(create: (_) => MaskProvider()),
        ChangeNotifierProvider(create: (_) => ScopeSettings()),
        ChangeNotifierProvider(create: (_) => AudioLevel()),
        ChangeNotifierProvider(create: (_) => Statistics()),
      ],
      child: MaterialApp(
        theme: thDefault,
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch},
        ),
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

void init() {
  // initialize Discord Rich presence
  DiscordRPC.initialize();
  rpcInitialize();

  // enable dithering for all painting (removes color banding)
  Paint.enableDithering = true;

  // initialize the ndi class
  ndi = NDI();
}

class Main extends StatefulWidget {
  const Main({Key? key}) : super(key: key);

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> with WindowListener {
  NDISource? selectedSource;
  bool refOpen = false;
  bool settingsOpen = false;
  bool portraitLayout = false;
  bool shutdown = false;

  final ScrollController _vScopeScroll = ScrollController();

  @override
  void initState() {
    // listen for window events
    windowManager.addListener(this);
    // set to manually close the app in the onWindowClose handler
    windowManager.setPreventClose(true).then((value) => setState(() {}));

    super.initState();

    // check GPU version
    checkGPU(context);

    // load settings from file
    loadSettings();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);

    _vScopeScroll.dispose();
    super.dispose();
  }

  loadSettings() {
    loadScopeSettings().then((s) {
      context.read<ScopeSettings>().update(s);
    });
  }

  @override
  void onWindowClose() async {
    setState(() {
      shutdown = true;
    });
    await ndi.dispose();
    windowManager.destroy();
  }

  void onSaveFrame() {
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
  }

  void onSelectSource(int index) async {
    final pS = ndi.getSourceAt(index);

    if (pS != null) {
      await ndi.stopGetFrames();
      await ndi.stopGetAudio();
      selectedSource = NDISource(pS);
      setState(() {});
      ndi.getFrames(
        selectedSource!.source,
        const Size(580, 256),
        (frame, rate, delay) => setState(
          () {
            context.read<Frame>().updateImageFrame(frame);
            final stats = context.read<Statistics>();
            stats.updateFrameRate(rate);
            stats.updateRenderDelay(delay);
            stats.calculateRenderFrameRate();
          },
        ),
        context.read<MaskProvider>().rect,
        context.read<MaskProvider>().active,
      );
      ndi.getAudio(
        pS,
        (level) {
          context.read<AudioLevel>().setLevels(level.channelLevels);
        },
        context.read<ScopeSettings>().audioOutputEnabled,
      );
    }
    rpcUpdate(selectedSource?.name);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      double aspect = constraints.maxWidth / constraints.maxHeight;
      portraitLayout = aspect < 1.3;
      int scopesCountX = portraitLayout ? 2 : 3;
      double width = constraints.maxWidth;
      if (context.watch<ScopeSettings>().audioLevelEnabled && !portraitLayout)
        width -= 125;
      if (!shutdown) {
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
                              onSaveFrame: () => onSaveFrame(),
                              onSelectSource: (index) => onSelectSource(index),
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
                          width: settingsOpen ? 175 : 0,
                          curve: Curves.easeInOutQuad,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const NeverScrollableScrollPhysics(),
                            child: SizedBox(
                              width: 175,
                              child: Settings(
                                onToggleAudioOut: (enabled) {
                                  ndi.updateAudio(enabled);
                                },
                              ),
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
                                controller: _vScopeScroll,
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
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IntrinsicHeight(
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
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
                        if (!portraitLayout)
                          SizedBox(
                            width: width / scopesCountX,
                            child: ScopeV2(
                              title: "RGB Parade",
                              img: context.watch<Frame>().imageFrame?.iWFParade,
                              ovl: context
                                  .watch<Frame>()
                                  .overlayFrame
                                  ?.iWFParade,
                              isParade: true,
                            ),
                          ),
                        if (context.watch<ScopeSettings>().audioLevelEnabled &&
                            !portraitLayout)
                          const AudioMeters(),
                      ],
                    ),
                  ),
                  if (portraitLayout)
                    IntrinsicHeight(
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          SizedBox(
                            width: width / scopesCountX,
                            child: ScopeV2(
                              title: "RGB Parade",
                              img: context.watch<Frame>().imageFrame?.iWFParade,
                              ovl: context
                                  .watch<Frame>()
                                  .overlayFrame
                                  ?.iWFParade,
                              isParade: true,
                            ),
                          ),
                          SizedBox(
                            width: width / scopesCountX / 2,
                            child: const VscopeV2(
                              title: "UV Vectorscope",
                            ),
                          ),
                          if (context.watch<ScopeSettings>().audioLevelEnabled)
                            const AudioMeters(),
                        ],
                      ),
                    ),
                ],
              ),
            )
          ],
        );
      } else {
        return Center(
          child: Text(
            "Shutting down...",
            style: tThin.copyWith(fontSize: 55),
          ),
        );
      }
    });
  }
}
