import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:dart_discord_rpc/dart_discord_rpc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ndiscopes/models/models.dart';
import 'package:ndiscopes/providers/providers.dart';
import 'package:ndiscopes/service/gfx/gfx.dart';
import 'package:ndiscopes/service/intents.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'package:ndiscopes/service/settings.dart';
import 'package:ndiscopes/service/textures/textures.dart';
import 'package:ndiscopes/service/discordrpc.dart';
import 'package:ndiscopes/util/saveloadframe.dart';
import 'package:ndiscopes/widgets/widgets.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

// DONE: Select Scope Types
// DONE: YUV Parade
// DONE: Don't render deselected scopes
// DONE: 15% Black Level View
// DONE: Visual Highlighting of focused buttons MISSING FrameBrowser and Settings
// DONE: Fix overlay when no frame present
// DONE: Per Scope Settings
// DONE: Per Scope Settings Menu
// DONE: Per Scope Overlays
// DONE: Show LoadingScreen/Splashscreen while loading settings
// DONE: Create Application folder on startup if not exist
// DONE: Keyboard shortcuts
// DONE: Prevent spamming S open multiple source dialogs
// TODO: Capture frame responsive
// TODO: Number hotkeys for different reference frames
// TODO: Scope specific settings
// TODO: Toggle Vectorscope Colorize
// TODO: Change Luminance Scope Color
// TODO: Audio Waveform
// TODO: Audio Spectrum
// TODO: Audio Vectorscope
// TODO: Color Space Coverage

void main() {
  // initialize components
  init();

  runApp(
    MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => Frame()),
      ChangeNotifierProvider(create: (_) => MaskProvider()),
      ChangeNotifierProvider(create: (_) => ScopeSettings()),
      ChangeNotifierProvider(create: (_) => AudioLevel()),
      ChangeNotifierProvider(create: (_) => Statistics()),
      ChangeNotifierProvider(create: (_) => AppStatus()),
    ], child: const Main()),
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
  bool portraitLayout = false;

  late ScrollController _vScopeScroll;
  late ScrollController _frameBrowserScroll;
  late ScrollController _settingsScroll;

  late Map<Type, Action<Intent>> _actions;

  final Map<ShortcutActivator, Intent> _shortcuts = {
    LogicalKeySet(LogicalKeyboardKey.keyC): ToggleFalseColorIntent(),
    LogicalKeySet(LogicalKeyboardKey.keyT): ToggleTransparencyIntent(),
    LogicalKeySet(LogicalKeyboardKey.keyX): ToggleSettingsIntent(),
    LogicalKeySet(LogicalKeyboardKey.keyB): ToggleFramebrowserIntent(),
    LogicalKeySet(LogicalKeyboardKey.keyM): ToggleMaskIntent(),
    LogicalKeySet(LogicalKeyboardKey.add): CaptureFrameIntent(),
    // for US Keyboard and other:
    const CharacterActivator("+"): CaptureFrameIntent(),
    LogicalKeySet(LogicalKeyboardKey.keyS): SelectSourceIntent(),
    LogicalKeySet(LogicalKeyboardKey.delete): DisableOverlayIntent(),
    LogicalKeySet(LogicalKeyboardKey.keyD): ToggleSplitDirection(),
    LogicalKeySet(LogicalKeyboardKey.keyF): ToggleSplitSide(),
  };

  GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    _vScopeScroll = ScrollController();
    _frameBrowserScroll = ScrollController();
    _settingsScroll = ScrollController();

    // add back default shortcuts
    // Focus and Scroll
    _shortcuts.addAll(WidgetsApp.defaultShortcuts);

    // override actions with custom actions
    _actions = {
      ToggleFalseColorIntent: CallbackAction<ToggleFalseColorIntent>(
        onInvoke: (intent) {
          context.read<Frame>().toggleFalseColor();
          return null;
        },
      ),
      ToggleTransparencyIntent: CallbackAction<ToggleTransparencyIntent>(
        onInvoke: (intent) {
          context.read<Frame>().toggleGrid();
          return null;
        },
      ),
      ToggleSettingsIntent: CallbackAction<ToggleSettingsIntent>(
        onInvoke: (intent) {
          context.read<AppStatus>().toggleSettings();
          return null;
        },
      ),
      ToggleFramebrowserIntent: CallbackAction<ToggleFramebrowserIntent>(
        onInvoke: (intent) {
          context.read<AppStatus>().toggleFrames();
          return null;
        },
      ),
      ToggleMaskIntent: CallbackAction<ToggleMaskIntent>(
        onInvoke: (intent) {
          final m = context.read<MaskProvider>();
          m.toggle();
          ndi.updateMask(m.rect, m.active);
          return null;
        },
      ),
      CaptureFrameIntent: CallbackAction<CaptureFrameIntent>(
        onInvoke: (intent) {
          onSaveFrame();
          return null;
        },
      ),
      SelectSourceIntent: CallbackAction<SelectSourceIntent>(
        onInvoke: (intent) {
          showSelectSource();
          return null;
        },
      ),
      DisableOverlayIntent: CallbackAction<DisableOverlayIntent>(
        onInvoke: (intent) {
          context.read<Frame>().toggleOverlay(enabled: false);
          return null;
        },
      ),
      ToggleSplitDirection: CallbackAction<ToggleSplitDirection>(
        onInvoke: (intent) {
          final frame = context.read<Frame>();
          frame.updateOverlayMode(
            frame.overlayMode != OverlayMode.splitVertical ? OverlayMode.splitVertical : OverlayMode.splitHorizontal,
          );
          return null;
        },
      ),
      ToggleSplitSide: CallbackAction<ToggleSplitSide>(
        onInvoke: (intent) {
          final frame = context.read<Frame>();
          frame.updateFlipSplit(!frame.flipSplit);
          return null;
        },
      ),
    };
    // add back default actions
    // Focus and Scroll
    _actions.addAll(WidgetsApp.defaultActions);

    // listen for window events
    windowManager.addListener(this);
    // set to manually close the app in the onWindowClose handler
    windowManager.setPreventClose(true).then((value) => setState(() {}));

    super.initState();

    initialize();
  }

  Future<void> initialize() async {
    // register all textures and notify parts of the ui when completed
    await initTextures();
    context.read<Frame>().toggleTexturesInitialized(initialized: true);
    await Future.delayed(const Duration(milliseconds: 150));
    context.read<AppStatus>().updateStatusText("initializing renderer...");
    await Future.delayed(const Duration(milliseconds: 150));
    // check GPU version
    context.read<AppStatus>().updateStatusText("checking GPU...");
    checkGPU(context);
    await Future.delayed(const Duration(milliseconds: 150));
    // load settings from file
    context.read<AppStatus>().updateStatusText("loading settings...");
    await loadSettings();
    await Future.delayed(const Duration(milliseconds: 150));

    context.read<AppStatus>().updateStatusText("");
    await Future.delayed(const Duration(milliseconds: 150));
    context.read<AppStatus>().toggleLoading(loading: false);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);

    _vScopeScroll.dispose();
    _frameBrowserScroll.dispose();
    _settingsScroll.dispose();
    super.dispose();
  }

  Future<void> loadSettings() async {
    ScopeSettings s = await loadScopeSettings();
    context.read<ScopeSettings>().update(s);
  }

  @override
  void onWindowClose() async {
    context.read<AppStatus>().updateStatusText("");
    context.read<AppStatus>().toggleShutdown(shutdown: true);
    context.read<AppStatus>().updateStatusText("shutting down NDI®...");
    await ndi.dispose();
    context.read<AppStatus>().updateStatusText("shutting down renderer...");
    await tr.dispose();
    rpcDispose();

    context.read<AppStatus>().updateStatusText("closing...");
    await windowManager.destroy();
    if (kDebugMode) print("exiting...");
  }

  void onSaveFrame() {
    if (selectedSource == null) return;
    // TODO: Make this better...!
    ndi.getSingleFrame(
      selectedSource!.source,
      (frame) {
        saveInputFrame(frame);
      },
      context.read<MaskProvider>().rect,
      context.read<MaskProvider>().active,
      context.read<ScopeSettings>().scopeTypes,
    );
  }

  void onSelectSource(int index) async {
    // index is -1 if stop butten was pressed
    if (index == -1) {
      await Future.wait([ndi.stopGetFrames(), ndi.stopGetAudio()]);
      selectedSource = null;
      rpcUpdate(null);
      setState(() {});
      return;
    }
    final pSource = ndi.getSourceAt(index);

    if (pSource != null) {
      await Future.wait([ndi.stopGetFrames(), ndi.stopGetAudio()]);

      // update the current selected source
      selectedSource = NDISource(pSource);
      setState(() {});

      // * START RECEIVING VIDEO
      ndi.getFrames(
        // the pointer to the current source
        selectedSource!.source,
        // the callback when a new frame arrives
        (rate, delay, size) {
          final stats = context.read<Statistics>();
          stats.update(frameRate: rate, renderDelay: delay, frameSize: size);
          stats.calculateRenderFrameRate();
        },
        // the current rect mask
        context.read<MaskProvider>().rect,
        // wether the mask is enabled
        context.read<MaskProvider>().active,
        // the currently active Scopes that need rendering
        context.read<ScopeSettings>().scopeTypes,
      );

      // * START RECEIVING AUDIO
      ndi.getAudio(
        selectedSource!.source,
        (level) {
          context.read<AudioLevel>().setLevels(level.channelLevels);
        },
        context.read<ScopeSettings>().audioOutputEnabled,
      );
    }
    // update the discord rich presence with the new source information (or null for NO SOURCE)
    rpcUpdate(selectedSource?.name);
  }

  bool _preventOpenSourceDialog = false;

  void showSelectSource() {
    if (_preventOpenSourceDialog) return;
    _preventOpenSourceDialog = true;
    showDialog(
      context: navKey.currentState?.overlay?.context ?? context,
      builder: (context) {
        return SourceSelectDialog(
          // pass the selected source to parent widget
          onSelectSource: onSelectSource,
        );
      },
    ).then((_) {
      _preventOpenSourceDialog = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ScopeSettings>();
    final status = context.watch<AppStatus>();

    return MaterialApp(
      navigatorKey: navKey,
      theme: thDefault,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch},
      ),
      debugShowCheckedModeBanner: false,
      shortcuts: _shortcuts,
      actions: _actions,
      home: Scaffold(
        backgroundColor: cAppBackground,
        body: LayoutBuilder(
          builder: (context, constraints) {
            double aspect = constraints.maxWidth / constraints.maxHeight;
            portraitLayout = aspect < 1.3;
            int scopesCountX = portraitLayout ? 2 : 3;
            double width = constraints.maxWidth;
            if (settings.audioLevelEnabled && !portraitLayout) {
              width -= 125;
            }

            if (status.shutdown) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Shutting down...",
                      style: tThin.copyWith(fontSize: 55),
                    ),
                    Text(
                      status.statusText,
                      style: tThin.copyWith(fontSize: 15),
                    ),
                  ],
                ),
              );
            }

            if (status.loading) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(
                      flex: 2,
                    ),
                    Text(
                      "NDIScopes",
                      style: tBold.copyWith(fontSize: 55),
                    ),
                    Text(
                      "by MindStudio",
                      style: tThin.copyWith(fontSize: 33),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          status.statusText,
                          style: tThin.copyWith(fontSize: 15),
                        ),
                      ),
                    ),
                    const Spacer()
                  ],
                ),
              );
            }

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
                            //* FRAME VIEWER
                            Expanded(
                              child: RepaintBoundary(
                                child: FrameViewer(
                                  onSaveFrame: onSaveFrame,
                                  onSelectSource: showSelectSource,
                                ),
                              ),
                            ),
                            //* FRAME BROWSER
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: status.framesOpen ? 175 : 0,
                              curve: Curves.easeInOutQuad,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const NeverScrollableScrollPhysics(),
                                controller: _frameBrowserScroll,
                                child: SizedBox(
                                  width: 175,
                                  child: FocusTraversalGroup(
                                    descendantsAreFocusable: status.framesOpen,
                                    descendantsAreTraversable: status.framesOpen,
                                    child: const FrameBrowserV2(),
                                  ),
                                ),
                              ),
                            ),
                            //* SETTINGS
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: status.settingsOpen ? 175 : 0,
                              curve: Curves.easeInOutQuad,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                controller: _settingsScroll,
                                physics: const NeverScrollableScrollPhysics(),
                                child: SizedBox(
                                  width: 175,
                                  child: FocusTraversalGroup(
                                    descendantsAreFocusable: status.settingsOpen,
                                    descendantsAreTraversable: status.settingsOpen,
                                    child: Settings(
                                      onToggleAudioOut: (enabled) {
                                        ndi.updateAudio(enabled);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      //* VSCOPE in portrait layout
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
                                    child: const VScope(
                                      title: "UV Vectorscope",
                                      imgId: TextureIDs.texVscope,
                                      ovlId: TextureIDs.texVscopeO,
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
                        child: FocusTraversalGroup(
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              SizedBox(
                                width: width / scopesCountX,
                                child: const ScopeSelector(
                                  layoutIndex: 0,
                                ),
                              ),
                              SizedBox(
                                width: width / scopesCountX,
                                child: const ScopeSelector(
                                  layoutIndex: 1,
                                ),
                              ),
                              if (!portraitLayout)
                                SizedBox(
                                  width: width / scopesCountX,
                                  child: const ScopeSelector(
                                    layoutIndex: 2,
                                  ),
                                ),
                              if (settings.audioLevelEnabled && !portraitLayout) const AudioMeters(),
                            ],
                          ),
                        ),
                      ),
                      if (portraitLayout)
                        IntrinsicHeight(
                          child: FocusTraversalGroup(
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                SizedBox(
                                  width: width / scopesCountX,
                                  child: const ScopeSelector(
                                    layoutIndex: 2,
                                  ),
                                ),
                                SizedBox(
                                  width: width / scopesCountX / 2,
                                  child: const VScope(
                                    title: "UV Vectorscope",
                                    imgId: TextureIDs.texVscope,
                                    ovlId: TextureIDs.texVscopeO,
                                  ),
                                ),
                                if (settings.audioLevelEnabled) const AudioMeters(),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }
}
