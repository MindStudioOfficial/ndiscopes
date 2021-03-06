import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ndiscopes/providers/appstatusprovider.dart';
import 'package:ndiscopes/providers/frameprovider.dart';
import 'package:ndiscopes/providers/maskprovider.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'package:ndiscopes/service/textures/textures.dart';
import 'dart:ui' as ui;
import 'package:ndiscopes/widgets/widgets.dart';
import 'package:provider/provider.dart';
import 'package:texturerender/texturerender.dart';
import 'package:ndiscopes/models/models.dart';

enum OverlayMode {
  splitVertical,
  splitHorizontal,
  opacity,
}

/// Displays the incoming NDI frames aswell as a selected overlay
/// and all necessary buttons for source selection reference frame controls and mask controls
class FrameViewer extends StatefulWidget {
  final Function() onSelectSource;
  final Function() onSaveFrame;

  const FrameViewer({
    Key? key,
    required this.onSelectSource,
    required this.onSaveFrame,
  }) : super(key: key);

  @override
  State<FrameViewer> createState() => _FrameViewerState();
}

class _FrameViewerState extends State<FrameViewer> {
  final ScrollController _buttonListScrollController = ScrollController();
  final ScrollController _falseColorOuterScollController = ScrollController();
  final ScrollController _falseColorInnerScollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // initiate mask with default value
    Future.delayed(const Duration(milliseconds: 50), () {
      context.read<MaskProvider>().updateRect(defaultMask(const Size(1920, 1080)));
    });
  }

  @override
  void dispose() {
    _buttonListScrollController.dispose();
    _falseColorInnerScollController.dispose();
    _falseColorOuterScollController.dispose();
    super.dispose();
  }

  // construct default rectangle for mask
  Rect defaultMask(Size frameSize) {
    Size maskSize = frameSize / 3;
    Offset maskOffset = Offset(frameSize.width / 3, frameSize.height / 3);
    return maskOffset & maskSize;
  }

  @override
  Widget build(BuildContext context) {
    final frame = context.watch<Frame>();
    final mask = context.watch<MaskProvider>();
    final status = context.watch<AppStatus>();

    bool texturesInitialized = frame.texturesInitialized;

    Widget imgw = texturesInitialized
        ? (frame.falseColorEnabled ? tr.widget(TextureIDs.texFalseC) : tr.widget(TextureIDs.texRGBA))
        : Container();
    Widget ovlw = texturesInitialized
        ? (frame.falseColorEnabled ? tr.widget(TextureIDs.texFalseCO) : tr.widget(TextureIDs.texRGBAO))
        : Container();

    ValueListenable<Tex>? texInfo = tr.textureInfo(TextureIDs.texRGBA);
    ValueListenable<Tex>? texInfoO = tr.textureInfo(TextureIDs.texRGBAO);

    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        //* button sidebar
        SingleChildScrollView(
          controller: _buttonListScrollController,
          child: FocusTraversalGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                //* select source button
                CustomIconButton(
                  tooltip: "Select NDI Source",
                  shortcutKeys: LogicalKeySet(LogicalKeyboardKey.keyS),
                  onPressed: () {
                    // pop-up dialog for selecting a source
                    widget.onSelectSource();
                  },
                  iconData: FluentIcons.video_24_regular,
                ),

                //* colored container for all reference frame related buttons
                Container(
                  // changes color when reference frame is selected
                  color: context.watch<Frame>().overlayEnabled ? cAccent : cPrimary,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      //* select reference frames
                      CustomIconButton(
                        shortcutKeys: LogicalKeySet(LogicalKeyboardKey.keyB),
                        tooltip: "${status.framesOpen ? "Close" : "Open"} Reference Frame Browser",
                        onPressed: status.toggleFrames,
                        iconData: FluentIcons.image_24_regular,
                        active: status.framesOpen,
                      ),

                      //* disable overlay button
                      if (context.watch<Frame>().overlayEnabled) ...[
                        CustomIconButton(
                          shortcutKeys: LogicalKeySet(LogicalKeyboardKey.delete),
                          tooltip: "Disable Overlay",
                          onPressed: () => frame.toggleOverlay(enabled: false),
                          iconData: FluentIcons.dismiss_24_regular,
                        ),
                        if (frame.overlayMode != OverlayMode.opacity) ...[
                          //* split mode toggle button
                          CustomIconButton(
                            shortcutKeys: LogicalKeySet(LogicalKeyboardKey.keyD),
                            tooltip: frame.overlayMode == OverlayMode.splitHorizontal
                                ? "Split Vertical"
                                : "Split Horizontal",
                            onPressed: () {
                              frame.updateOverlayMode(
                                frame.overlayMode == OverlayMode.splitHorizontal
                                    ? OverlayMode.splitVertical
                                    : OverlayMode.splitHorizontal,
                              );
                            },
                            iconData: frame.overlayMode == OverlayMode.splitHorizontal
                                ? FluentIcons.split_vertical_24_regular
                                : FluentIcons.split_horizontal_24_regular,
                          ),

                          //* flip overlay toogle button
                          CustomIconButton(
                            shortcutKeys: LogicalKeySet(LogicalKeyboardKey.keyF),
                            tooltip: "Flip Overlay Side",
                            onPressed: () => frame.updateFlipSplit(!frame.flipSplit),
                            iconData: frame.overlayMode == OverlayMode.splitHorizontal
                                ? FluentIcons.flip_vertical_24_regular
                                : FluentIcons.flip_horizontal_24_regular,
                          ),
                        ]
                      ],
                      //* save reference frame button
                      CustomIconButton(
                        shortcutKeys: LogicalKeySet(LogicalKeyboardKey.add),
                        tooltip: "Save Reference Frame",
                        onPressed: () {
                          widget.onSaveFrame();
                        },
                        iconData: FluentIcons.camera_add_24_regular,
                        loading: status.capturingFrame,
                      ),
                    ],
                  ),
                ),
                //* mask related buttons
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    //* toogle mask button

                    CustomIconButton(
                      shortcutKeys: LogicalKeySet(LogicalKeyboardKey.keyM),
                      tooltip: "Toogle Mask",
                      onPressed: () {
                        ndi.updateMask(mask.rect, !mask.active);
                        mask.toggle();
                      },
                      iconData: FluentIcons.crop_24_regular,
                      active: mask.active,
                    ),

                    //* reset mask button
                    if (mask.active)
                      texInfo != null
                          ? ValueListenableBuilder<Tex>(
                              valueListenable: texInfo,
                              builder: (context, tex, _) {
                                return CustomIconButton(
                                  tooltip: "Reset Mask",
                                  onPressed: () {
                                    Rect m = defaultMask(tex.size);
                                    mask.updateRect(m);
                                    ndi.updateMask(m, mask.active);
                                  },
                                  iconData: FluentIcons.arrow_reset_24_regular,
                                );
                              },
                            )
                          : CustomIconButton(
                              tooltip: "Reset Mask",
                              onPressed: () {
                                Rect m = defaultMask(const Size(1920, 1080));
                                mask.updateRect(m);
                                ndi.updateMask(m, mask.active);
                              },
                              iconData: FluentIcons.arrow_reset_24_regular,
                            ),
                  ],
                ),
                CustomIconButton(
                  shortcutKeys: LogicalKeySet(LogicalKeyboardKey.keyT),
                  tooltip: "Toggle Transparancy Grid",
                  onPressed: frame.toggleGrid,
                  iconData: FluentIcons.tab_in_private_24_regular,
                  active: frame.gridEnabled,
                ),
                CustomIconButton(
                  shortcutKeys: LogicalKeySet(LogicalKeyboardKey.keyC),
                  tooltip: "Toggle False Color",
                  onPressed: frame.toggleFalseColor,
                  iconData: FluentIcons.color_24_regular,
                  active: frame.falseColorEnabled,
                ),
                CustomIconButton(
                  shortcutKeys: LogicalKeySet(LogicalKeyboardKey.keyX),
                  tooltip: "Toggle Settings",
                  onPressed: status.toggleSettings,
                  iconData: FluentIcons.settings_24_regular,
                  active: status.settingsOpen,
                ),
              ],
            ),
          ),
        ),
        //* False Color Scale
        FalseColorScale(
          falseColorInnerScollController: _falseColorInnerScollController,
          falseColorOuterScollController: _falseColorOuterScollController,
        ),
        //* frame viewer
        texInfo != null
            ? ValueListenableBuilder<Tex>(
                valueListenable: texInfo,
                builder: (context, tex, _) {
                  Size s = tex.size.isEmpty
                      ? (texInfoO != null && !texInfoO.value.size.isEmpty
                          ? texInfoO.value.size
                          : const Size(1920, 1080))
                      : tex.size;
                  return Expanded(
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: ClipRect(
                          child: Stack(
                            children: [
                              if (frame.gridEnabled)
                                SizedBox(
                                  width: s.width,
                                  height: s.height,
                                  child: Image.asset(
                                    "graphics/transparency500.png",
                                    repeat: ImageRepeat.repeat,
                                    alignment: Alignment.topLeft,
                                  ),
                                ),

                              //* NDI SOURCE IMAGE + Overlay
                              imgw,
                              if (frame.overlayEnabled)
                                Split(
                                  child: ovlw,
                                  tex: tex,
                                  texO: texInfoO?.value,
                                ),

                              //* Mask Overlay
                              if (mask.active)
                                Mask(
                                  frameSize: Size(
                                    s.width,
                                    s.height,
                                  ),
                                ),
                              //* Overlay slider vertical
                              if (frame.overlayEnabled && frame.overlayMode == OverlayMode.splitVertical)
                                Positioned(
                                  left: (s.width) * frame.splitPos - 22.5,
                                  top: (s.height) / 2 - 22.5,
                                  child: Listener(
                                    onPointerMove: (event) {
                                      frame.updateSplitPos(
                                        (frame.splitPos + event.localDelta.dx / (s.width)).clamp(0, 1),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(22.5),
                                      child: Container(
                                        width: 45,
                                        height: 45,
                                        color: Colors.black.withOpacity(.7),
                                        child: const Center(
                                          child: Icon(
                                            FluentIcons.auto_fit_width_24_filled,
                                            color: Colors.white,
                                            size: 35,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              //* Overlay slider horizontal
                              if (frame.overlayEnabled && frame.overlayMode == OverlayMode.splitHorizontal)
                                Positioned(
                                  left: (s.width) / 2 - 22.5,
                                  top: (s.height) * frame.splitPos - 22.5,
                                  child: Listener(
                                    onPointerMove: (event) {
                                      frame.updateSplitPos(
                                        (frame.splitPos + event.localDelta.dy / (s.height)).clamp(0, 1),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(22.5),
                                      child: Container(
                                        width: 45,
                                        height: 45,
                                        color: Colors.black.withOpacity(.7),
                                        child: const Center(
                                          child: Icon(
                                            FluentIcons.auto_fit_height_24_filled,
                                            color: Colors.white,
                                            size: 35,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              )
            : Expanded(
                child: Container(),
              ),
      ],
    );
  }
}

/// Paints the [img] and optional [overlay] on top.

class ImagePainter extends CustomPainter {
  ui.Image? img;
  ui.Image? overlay;
  double? opacity;
  BlendMode? bm;
  double splitPos;
  bool flipSplit;
  OverlayMode overlayMode;
  ImagePainter({
    required this.img,
    this.bm,
    this.overlay,
    this.opacity,
    required this.flipSplit,
    required this.splitPos,
    required this.overlayMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // calculate original aspectratios
    double imgAspect = (img?.width ?? 16) / (img?.height ?? 9);
    double ovlAspect = (overlay?.width ?? 16) / (overlay?.height ?? 9);

    // decide how to resize the overlay based on the aspectratios
    bool sizeByHeight = imgAspect > ovlAspect;

    Size imageSize = Size(img?.width.toDouble() ?? 1920, img?.height.toDouble() ?? 1080);
    Size overlaySize = Size(overlay?.width.toDouble() ?? 1920, overlay?.height.toDouble() ?? 1080);

    // resize the overlay to fit within the image based on aspect ratios
    Size resizedOverlaySize =
        overlaySize * (sizeByHeight ? (imageSize.height / overlaySize.height) : (imageSize.width / overlaySize.width));

    // calculate the topleft corner of the overlay to center it on the screen
    Offset ovlTopLeft = Offset(
      (imageSize.width - resizedOverlaySize.width) / 2,
      (imageSize.height - resizedOverlaySize.height) / 2,
    );

    Paint p = Paint()..blendMode = bm ?? BlendMode.srcOver;
    p.colorFilter = const ColorFilter.matrix(
      //* make alpha only dependant on input alpha
      //* default seems to be to expect a premultiplied image
      <double>[
        // r g b a o
        1, 0, 0, 0, 0, // r
        0, 1, 0, 0, 0, // g
        0, 0, 1, 0, 0, // b
        0, 0, 0, 1, 0, // a
      ],
    );
    // fill background with black if no image
    // ClipRect is necessary around this painter because this doesn't respect canvas boundaries
    if (img == null) {
      canvas.drawColor(Colors.black, BlendMode.srcOver);
    }
    // paint the image if available
    else {
      canvas.drawImage(img!, Offset.zero, p);
    }
    // paints the overlay image if available
    if (overlay != null) {
      switch (overlayMode) {
        //! not used but still here just in case
        case OverlayMode.opacity:
          p.color = Colors.black.withOpacity(opacity ?? .5);
          canvas.drawImage(overlay!, Offset.zero, p);
          break;
        // splits the overlay image vertically based on split position and flip
        case OverlayMode.splitVertical:
          p.color = Colors.white;
          Size cutOverlaySize =
              Size(flipSplit ? overlay!.width * (1 - splitPos) : overlay!.width * splitPos, overlay!.height.toDouble());

          Size cutReSizedOverlaySize = Size(
              flipSplit ? resizedOverlaySize.width * (1 - splitPos) : resizedOverlaySize.width * splitPos,
              resizedOverlaySize.height.toDouble());

          canvas.drawImageRect(
            overlay!,
            Offset(flipSplit ? overlay!.width * splitPos : 0, 0) & cutOverlaySize,
            Offset(
                  flipSplit ? resizedOverlaySize.width * splitPos + ovlTopLeft.dx : ovlTopLeft.dx,
                  ovlTopLeft.dy,
                ) &
                cutReSizedOverlaySize,
            p,
          );
          break;
        // splits the overlay image horizontally based on split position and flip
        case OverlayMode.splitHorizontal:
          p.color = Colors.white;
          Size cutOverlaySize = Size(
              overlay!.width.toDouble(), flipSplit ? overlay!.height * (1 - splitPos) : overlay!.height * splitPos);

          Size cutReSizedOverlaySize = Size(resizedOverlaySize.width.toDouble(),
              flipSplit ? resizedOverlaySize.height * (1 - splitPos) : resizedOverlaySize.height * splitPos);

          canvas.drawImageRect(
            overlay!,
            Offset(0, flipSplit ? overlay!.height * splitPos : 0) & cutOverlaySize,
            Offset(ovlTopLeft.dx, flipSplit ? resizedOverlaySize.height * splitPos + ovlTopLeft.dy : ovlTopLeft.dy) &
                cutReSizedOverlaySize,
            p,
          );
          break;
        default:
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

/// displays the mask with control points
// ignore: must_be_immutable
class Mask extends StatelessWidget {
  final Size frameSize;
  const Mask({Key? key, required this.frameSize}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mask = context.watch<MaskProvider>();
    return Stack(
      children: [
        //* paints the outside of the mask slightly black
        CustomPaint(
          size: frameSize,
          painter: MaskPainter(mask: mask.rect),
        ),
        //* the actual rectangle with white borders that can be moved around
        Positioned(
          top: mask.rect.top,
          left: mask.rect.left,
          child: MouseRegion(
            cursor: SystemMouseCursors.move,
            child: Listener(
              //* listen for move events
              onPointerMove: (event) {
                Rect newMask = mask.rect.shift(event.localDelta);
                //* move the mask but not outside the frame
                newMask = Offset(
                      newMask.topLeft.dx.clamp(0, frameSize.width - newMask.width),
                      newMask.topLeft.dy.clamp(0, frameSize.height - newMask.height),
                    ) &
                    newMask.size;
                //* update the mask
                mask.updateRect(newMask);
                ndi.updateMask(newMask, mask.active);
              },
              //* the actual white border of the mask rectangle
              child: Container(
                width: mask.rect.width,
                height: mask.rect.height,
                decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2)),
              ),
            ),
          ),
        ),
        //* top left resize control
        Positioned(
          top: mask.rect.topLeft.dy - 15,
          left: mask.rect.topLeft.dx - 15,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
            child: Listener(
              //* listen for move events
              onPointerMove: (event) {
                Size newSize = (mask.rect.size + -(event.localDelta));
                Offset newPos = (mask.rect.topLeft + event.localDelta);

                newPos = Offset(
                  newPos.dx.clamp(0, frameSize.width),
                  newPos.dy.clamp(0, frameSize.height),
                );
                newSize = Size(
                  newSize.width.clamp(0, frameSize.width - newPos.dx),
                  newSize.height.clamp(0, frameSize.height - newPos.dy),
                );

                mask.updateRect(newPos & newSize);
                ndi.updateMask(newPos & newSize, mask.active);
              },
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
              ),
            ),
          ),
        ),
        //* bottom right resize control
        Positioned(
          top: mask.rect.bottomRight.dy - 15,
          left: mask.rect.bottomRight.dx - 15,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
            child: Listener(
              //* listen for move events
              onPointerMove: (event) {
                Size newSize = (mask.rect.size + event.localDelta);

                newSize = Size(
                  newSize.width.clamp(0, frameSize.width - mask.rect.topLeft.dx),
                  newSize.height.clamp(0, frameSize.height - mask.rect.topLeft.dy),
                );
                ndi.updateMask(mask.rect.topLeft & newSize, mask.active);
                mask.updateRect(mask.rect.topLeft & newSize);
              },
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Paints a rectangle cutout corresponding to the mask rect
///
/// overlays everything outside the mask with 70% black
class MaskPainter extends CustomPainter {
  final Rect mask;
  const MaskPainter({required this.mask});

  @override
  void paint(Canvas canvas, Size size) {
    Paint p = Paint()..color = Colors.black.withOpacity(.7);
    canvas.drawPath(
      // make a large rectangle with a small rectangle cut out
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRect(mask),
      ),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class Split extends StatelessWidget {
  final Widget child;
  final Tex tex;
  final Tex? texO;
  const Split({Key? key, required this.child, required this.tex, required this.texO}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final frame = context.watch<Frame>();
    Size s = tex.size.isEmpty ? (texO != null && !texO!.size.isEmpty ? texO!.size : const Size(1920, 1080)) : tex.size;

    return SizedBox(
      width: s.width,
      height: s.height,
      child: Align(
        alignment: splitAlignment(frame.overlayMode, frame.flipSplit),
        child: ClipRect(
          child: Align(
            alignment: splitAlignment(frame.overlayMode, frame.flipSplit),
            widthFactor: frame.overlayMode == OverlayMode.splitVertical
                ? (frame.flipSplit ? 1 - frame.splitPos : frame.splitPos)
                : null,
            heightFactor: frame.overlayMode == OverlayMode.splitHorizontal
                ? (frame.flipSplit ? 1 - frame.splitPos : frame.splitPos)
                : null,
            child: SizedBox(
              width: s.width,
              height: s.height,
              child: FittedBox(
                fit: BoxFit.fitWidth,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Alignment splitAlignment(OverlayMode mode, bool flip) {
    switch (mode) {
      case OverlayMode.splitHorizontal:
        if (flip) return Alignment.bottomCenter;
        return Alignment.topCenter;
      case OverlayMode.splitVertical:
        if (flip) return Alignment.centerRight;
        return Alignment.centerLeft;
      default:
        return Alignment.center;
    }
  }
}
