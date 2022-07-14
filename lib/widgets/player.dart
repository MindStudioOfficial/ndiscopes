import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  final Function(int index) onSelectSource;
  final Function() onSaveFrame;
  final Function(bool open) onToggleFrameBrowser;
  final Function(bool open) onToggleSettings;

  const FrameViewer({
    Key? key,
    required this.onSelectSource,
    required this.onSaveFrame,
    required this.onToggleFrameBrowser,
    required this.onToggleSettings,
  }) : super(key: key);

  @override
  State<FrameViewer> createState() => _FrameViewerState();
}

class _FrameViewerState extends State<FrameViewer> {
  bool frameBrowserOpen = false;
  bool settingsOpen = false;

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

    bool texturesInitialized = frame.texturesInitialized;

    Widget imgw = texturesInitialized
        ? (frame.falseColorEnabled ? tr.widget(TextureIDs.texFalseC) : tr.widget(TextureIDs.texRGBA))
        : Container();
    Widget ovlw = texturesInitialized
        ? (frame.falseColorEnabled ? tr.widget(TextureIDs.texFalseCO) : tr.widget(TextureIDs.texRGBAO))
        : Container();

    ValueListenable<Tex>? texInfo = tr.textureInfo(TextureIDs.texRGBA);

    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        //* button sidebar
        SingleChildScrollView(
          controller: _buttonListScrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              //* select source button
              DelayedCustomTooltip(
                "Select NDI Source",
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: IconButton(
                    onPressed: () {
                      // pop-up dialog for selecting a source
                      showDialog(
                        context: context,
                        builder: (context) {
                          return SourceSelectDialog(
                            // pass the selected source to parent widget
                            onSelectSource: (widget.onSelectSource),
                          );
                        },
                      );
                    },
                    iconSize: 25,
                    color: Colors.white,
                    icon: const Icon(
                      FluentIcons.video_clip_24_filled,
                    ),
                  ),
                ),
              ),
              //* colored container for all reference frame related buttons
              Container(
                // changes color when reference frame is selected
                color: context.watch<Frame>().overlayEnabled ? cAccent : cPrimary,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    //* select reference frames
                    DelayedCustomTooltip(
                      "Select Reference Frame",
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: IconButton(
                          onPressed: () {
                            frameBrowserOpen = !frameBrowserOpen;
                            widget.onToggleFrameBrowser(frameBrowserOpen);
                          },
                          iconSize: 25,
                          color: frameBrowserOpen ? Colors.blue : Colors.white,
                          icon: const Icon(
                            FluentIcons.image_28_filled,
                          ),
                        ),
                      ),
                    ),
                    //* disable overlay button
                    if (context.watch<Frame>().overlayEnabled) ...[
                      DelayedCustomTooltip(
                        "Disable Overlay",
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: IconButton(
                            iconSize: 25,
                            color: Colors.white,
                            onPressed: () {
                              frame.toggleOverlay(enabled: false);
                            },
                            icon: const Icon(FluentIcons.dismiss_24_filled),
                          ),
                        ),
                      ),
                      if (frame.overlayMode != OverlayMode.opacity) ...[
                        //* split mode toggle button
                        DelayedCustomTooltip(
                          frame.overlayMode == OverlayMode.splitHorizontal ? "Split Vertical" : "Split Horizontal",
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: IconButton(
                              iconSize: 25,
                              color: Colors.white,
                              onPressed: () {
                                frame.updateOverlayMode(
                                  frame.overlayMode == OverlayMode.splitHorizontal
                                      ? OverlayMode.splitVertical
                                      : OverlayMode.splitHorizontal,
                                );

                                //widget.onOverlayChanged(overlayMode, splitPos, flipSplit);
                                //setState(() {});
                              },
                              icon: Icon(
                                frame.overlayMode == OverlayMode.splitHorizontal
                                    ? FluentIcons.split_vertical_28_regular
                                    : FluentIcons.split_horizontal_28_regular,
                              ),
                            ),
                          ),
                        ),
                        //* flip overlay toogle button
                        DelayedCustomTooltip(
                          "Flip Overlay Side",
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: IconButton(
                              iconSize: 25,
                              color: frame.flipSplit ? cHighlight : Colors.white,
                              onPressed: () {
                                frame.updateFlipSplit(!frame.flipSplit);
                                //flipSplit = !flipSplit;
                                //widget.onOverlayChanged(overlayMode, splitPos, flipSplit);
                              },
                              icon: Icon(
                                frame.overlayMode == OverlayMode.splitHorizontal
                                    ? FluentIcons.flip_vertical_24_regular
                                    : FluentIcons.flip_horizontal_24_regular,
                              ),
                            ),
                          ),
                        ),
                      ]
                    ],
                    //* save reference frame button
                    DelayedCustomTooltip(
                      "Save Reference Frame",
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: IconButton(
                          iconSize: 25,
                          color: Colors.white,
                          onPressed: () {
                            widget.onSaveFrame();
                          },
                          icon: const Icon(FluentIcons.image_add_24_filled),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              //* mask related buttons
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  //* toogle mask button
                  DelayedCustomTooltip(
                    "Toogle Mask",
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: IconButton(
                        color: mask.active ? cHighlight : Colors.white,
                        iconSize: 25,
                        icon: const Icon(FluentIcons.crop_24_filled),
                        onPressed: () {
                          ndi.updateMask(mask.rect, !mask.active);
                          mask.toogle();
                        },
                      ),
                    ),
                  ),
                  //* reset mask button
                  if (mask.active)
                    DelayedCustomTooltip(
                      "Reset Mask",
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: texInfo != null
                            ? ValueListenableBuilder<Tex>(
                                valueListenable: texInfo,
                                builder: (context, tex, _) {
                                  return IconButton(
                                    onPressed: () {
                                      Rect m = defaultMask(tex.size);
                                      mask.updateRect(m);
                                      ndi.updateMask(m, mask.active);
                                    },
                                    color: Colors.white,
                                    iconSize: 25,
                                    icon: const Icon(
                                      FluentIcons.arrow_reset_24_filled,
                                    ),
                                  );
                                })
                            : IconButton(
                                onPressed: () {
                                  Rect m = defaultMask(const Size(1920, 1080));
                                  mask.updateRect(m);
                                  ndi.updateMask(m, mask.active);
                                },
                                color: Colors.white,
                                iconSize: 25,
                                icon: const Icon(
                                  FluentIcons.arrow_reset_24_filled,
                                ),
                              ),
                      ),
                    ),
                ],
              ),
              DelayedCustomTooltip(
                "Toogle Transparancy Grid",
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton(
                    color: frame.gridEnabled ? cHighlight : Colors.white,
                    iconSize: 25,
                    icon: const Icon(FluentIcons.tab_in_private_24_filled),
                    onPressed: () {
                      frame.toogleGrid();
                    },
                  ),
                ),
              ),
              DelayedCustomTooltip(
                "Toogle False Color",
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton(
                    color: frame.falseColorEnabled ? cHighlight : Colors.white,
                    iconSize: 25,
                    icon: const Icon(FluentIcons.color_24_filled),
                    onPressed: () {
                      frame.toggleFalseColor();
                    },
                  ),
                ),
              ),
              DelayedCustomTooltip(
                "Toogle Settings",
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton(
                    color: settingsOpen ? cHighlight : Colors.white,
                    iconSize: 25,
                    icon: const Icon(FluentIcons.settings_24_filled),
                    onPressed: () {
                      settingsOpen = !settingsOpen;
                      widget.onToggleSettings(settingsOpen);
                    },
                  ),
                ),
              ),
            ],
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
                                  width: tex.size.width,
                                  height: tex.size.height,
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
                                ),

                              //* Mask Overlay
                              if (mask.active)
                                Mask(
                                  frameSize: Size(
                                    tex.size.width,
                                    tex.size.height,
                                  ),
                                ),
                              //* Overlay slider vertical
                              if (frame.overlayEnabled && frame.overlayMode == OverlayMode.splitVertical)
                                Positioned(
                                  left: (tex.size.width) * frame.splitPos - 22.5,
                                  top: (tex.size.height) / 2 - 22.5,
                                  child: Listener(
                                    onPointerMove: (event) {
                                      frame.updateSplitPos(
                                        (frame.splitPos + event.localDelta.dx / (tex.size.width)).clamp(0, 1),
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
                                  left: (tex.size.width) / 2 - 22.5,
                                  top: (tex.size.height) * frame.splitPos - 22.5,
                                  child: Listener(
                                    onPointerMove: (event) {
                                      frame.updateSplitPos(
                                        (frame.splitPos + event.localDelta.dy / (tex.size.height)).clamp(0, 1),
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
  const Split({Key? key, required this.child, required this.tex}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final frame = context.watch<Frame>();

    return SizedBox(
      width: tex.size.width,
      height: tex.size.height,
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
              width: tex.size.width,
              height: tex.size.height,
              child: FittedBox(
                fit: BoxFit.contain,
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
