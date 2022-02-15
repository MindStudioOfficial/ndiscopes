import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:ndiscopes/main.dart';
import 'package:ndiscopes/models/colors.dart';
import 'package:ndiscopes/models/textstyles.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'dart:ui' as ui;

import 'package:ndiscopes/widgets/customtooltip.dart';

enum OverlayMode {
  splitVertical,
  splitHorizontal,
  opacity,
}

class FrameViewer extends StatefulWidget {
  final NDIOutputFrame? frame;
  final NDIOutputFrame? overlay;
  final double? overlayOpacity;
  final Function(int index) onSelectSource;
  final Function() onSaveFrame;
  final Function() onRemoveOverlay;
  final Function(OverlayMode mode, double splitPos, bool flipSplit) onOverlayChanged;
  final Function(Rect mask, bool active) onMaskUpdate;
  const FrameViewer({
    Key? key,
    required this.frame,
    required this.onSelectSource,
    this.overlay,
    this.overlayOpacity,
    required this.onSaveFrame,
    required this.onRemoveOverlay,
    required this.onOverlayChanged,
    required this.onMaskUpdate,
  }) : super(key: key);

  @override
  State<FrameViewer> createState() => _FrameViewerState();
}

class _FrameViewerState extends State<FrameViewer> {
  OverlayMode overlayMode = OverlayMode.splitVertical;
  double splitPos = 0.5;
  bool flipSplit = false;

  bool maskActive = false;

  late Rect mask;

  @override
  void initState() {
    super.initState();
    mask = defaultMask();
  }

  Rect defaultMask() {
    Size frameSize = widget.frame != null
        ? Size(widget.frame!.iRGBA.width.toDouble(), widget.frame!.iRGBA.height.toDouble())
        : const Size(1920, 1080);
    Size maskSize = frameSize / 3;
    Offset maskOffset = Offset(frameSize.width / 3, frameSize.height / 3);
    return maskOffset & maskSize;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: FittedBox(
              fit: BoxFit.contain,
              child: ClipRect(
                child: Stack(
                  children: [
                    // * NDI SOURCE IMAGE + Overlay
                    CustomPaint(
                      painter: ImagePainter(
                        img: widget.frame != null ? widget.frame!.iRGBA : null,
                        overlay: widget.overlay != null ? widget.overlay!.iRGBA : null,
                        opacity: widget.overlayOpacity,
                        flipSplit: flipSplit,
                        splitPos: splitPos,
                        overlayMode: overlayMode,
                      ),
                      size: Size(
                        widget.frame != null ? widget.frame!.iRGBA.width.toDouble() : 1920,
                        widget.frame != null ? widget.frame!.iRGBA.height.toDouble() : 1080,
                      ),
                    ),
                    // * Mask Overlay
                    if (maskActive)
                      Mask(
                        frameSize: Size(
                          widget.frame != null ? widget.frame!.iRGBA.width.toDouble() : 1920,
                          widget.frame != null ? widget.frame!.iRGBA.height.toDouble() : 1080,
                        ),
                        onMaskUpdated: (m) {
                          mask = m;
                          widget.onMaskUpdate(m, maskActive);
                        },
                        mask: mask,
                      ),
                    // * Overlay sliders
                    if (widget.overlay != null && overlayMode == OverlayMode.splitVertical)
                      Positioned(
                        left: widget.overlay!.iRGBA.width * splitPos - 22.5,
                        top: widget.overlay!.iRGBA.height / 2 - 22.5,
                        child: Listener(
                          onPointerMove: (event) {
                            splitPos = (splitPos + event.localDelta.dx / widget.overlay!.iRGBA.width).clamp(0, 1);
                            widget.onOverlayChanged(overlayMode, splitPos, flipSplit);
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
                    if (widget.overlay != null && overlayMode == OverlayMode.splitHorizontal)
                      Positioned(
                        left: widget.overlay!.iRGBA.width / 2 - 22.5,
                        top: widget.overlay!.iRGBA.height * splitPos - 22.5,
                        child: Listener(
                          onPointerMove: (event) {
                            splitPos = (splitPos + event.localDelta.dy / widget.overlay!.iRGBA.height).clamp(0, 1);
                            widget.onOverlayChanged(overlayMode, splitPos, flipSplit);
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
        ),
        // * Source Select Button
        Align(
          alignment: Alignment.topLeft,
          child: DelayedCustomTooltip(
            "Select NDI Source",
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return SourceSelectDialog(
                        onSelectSource: widget.onSelectSource,
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
        ),
        // * OVERLAY BUTTONS
        Align(
          alignment: Alignment.bottomRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.overlay != null) ...[
                DelayedCustomTooltip(
                  "Disable Overlay",
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconButton(
                      iconSize: 25,
                      color: Colors.white,
                      onPressed: () {
                        widget.onRemoveOverlay();
                      },
                      icon: const Icon(FluentIcons.dismiss_24_filled),
                    ),
                  ),
                ),
                if (overlayMode != OverlayMode.opacity) ...[
                  DelayedCustomTooltip(
                    overlayMode == OverlayMode.splitHorizontal ? "Split Vertical" : "Split Horizontal",
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IconButton(
                        iconSize: 25,
                        color: Colors.white,
                        onPressed: () {
                          overlayMode = overlayMode == OverlayMode.splitHorizontal
                              ? OverlayMode.splitVertical
                              : OverlayMode.splitHorizontal;
                          widget.onOverlayChanged(overlayMode, splitPos, flipSplit);
                          //setState(() {});
                        },
                        icon: Icon(
                          overlayMode == OverlayMode.splitHorizontal
                              ? FluentIcons.split_vertical_28_regular
                              : FluentIcons.split_horizontal_28_regular,
                        ),
                      ),
                    ),
                  ),
                  DelayedCustomTooltip(
                    "Flip Overlay Side",
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IconButton(
                        iconSize: 25,
                        color: Colors.white,
                        onPressed: () {
                          flipSplit = !flipSplit;
                          widget.onOverlayChanged(overlayMode, splitPos, flipSplit);
                        },
                        icon: Icon(
                          overlayMode == OverlayMode.splitHorizontal
                              ? FluentIcons.flip_vertical_24_regular
                              : FluentIcons.flip_horizontal_24_regular,
                        ),
                      ),
                    ),
                  ),
                ]
              ],
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
        // * MASK BUTTONS
        Align(
          alignment: Alignment.bottomLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DelayedCustomTooltip(
                "Toogle Mask",
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton(
                    color: maskActive ? Colors.blue : Colors.white,
                    iconSize: 25,
                    icon: const Icon(FluentIcons.crop_24_filled),
                    onPressed: () {
                      maskActive = !maskActive;
                      widget.onMaskUpdate(mask, maskActive);
                    },
                  ),
                ),
              ),
              if (maskActive)
                DelayedCustomTooltip(
                  "Reset Mask",
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: IconButton(
                      onPressed: () {
                        setState(() {
                          mask = defaultMask();
                        });
                        widget.onMaskUpdate(defaultMask(), maskActive);
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
        ),
      ],
    );
  }
}

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
    Paint p = Paint()..blendMode = bm ?? BlendMode.srcOver;
    canvas.drawColor(Colors.black, BlendMode.srcOver);
    if (img != null) {
      canvas.drawImage(img!, Offset.zero, p);
    }
    if (overlay != null) {
      switch (overlayMode) {
        case OverlayMode.opacity:
          p.color = Colors.black.withOpacity(opacity ?? .5);
          canvas.drawImage(overlay!, Offset.zero, p);
          break;
        case OverlayMode.splitVertical:
          p.color = Colors.white;
          Size overlaySize =
              Size(flipSplit ? overlay!.width * (1 - splitPos) : overlay!.width * splitPos, overlay!.height.toDouble());
          canvas.drawImageRect(
            overlay!,
            Offset(flipSplit ? overlay!.width * splitPos : 0, 0) & overlaySize,
            Offset(flipSplit ? overlay!.width * splitPos : 0, 0) & overlaySize,
            p,
          );

          break;
        case OverlayMode.splitHorizontal:
          p.color = Colors.white;
          canvas.drawImageRect(
            overlay!,
            Offset(0, flipSplit ? overlay!.height * splitPos : 0) &
                Size(overlay!.width.toDouble(),
                    flipSplit ? overlay!.height * (1 - splitPos) : overlay!.height * splitPos),
            Offset(0, flipSplit ? overlay!.height * splitPos : 0) &
                Size(overlay!.width.toDouble(),
                    flipSplit ? overlay!.height * (1 - splitPos) : overlay!.height * splitPos),
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

class SourceSelectDialog extends StatefulWidget {
  final Function(int index) onSelectSource;
  const SourceSelectDialog({Key? key, required this.onSelectSource}) : super(key: key);

  @override
  _SourceSelectDialogState createState() => _SourceSelectDialogState();
}

class _SourceSelectDialogState extends State<SourceSelectDialog> {
  bool loading = true;
  @override
  void initState() {
    super.initState();
    ndi.updateSoures().then((_) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      backgroundColor: cDialogBackground,
      elevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Select Source",
            style: tDefault,
          ),
          DelayedCustomTooltip(
            "Refresh",
            child: IconButton(
              onPressed: (() {
                loading = true;
                setState(() {});
                ndi.updateSoures().then((_) {
                  setState(() {
                    loading = false;
                  });
                });
              }),
              color: Colors.white,
              iconSize: 25,
              icon: const Icon(Icons.refresh_sharp),
            ),
          ),
        ],
      ),
      children: [
        if (loading)
          const Center(
            child: SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          ),
        if (!loading && ndi.sources.isEmpty)
          Center(
            child: Text(
              "No Sources Found",
              style: tAccent,
            ),
          ),
        SizedBox(
          height: 300,
          width: 300,
          child: ListView.builder(
            itemCount: ndi.sources.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                child: Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      ndi.sources[index].name,
                      style: tSmall,
                    ),
                  ),
                  color: cSourceCard,
                  shape: Border.all(),
                ),
                onTap: () {
                  widget.onSelectSource(index);
                  Navigator.pop(context);
                },
              );
            },
          ),
        )
      ],
    );
  }
}

class Mask extends StatefulWidget {
  final Size frameSize;
  final Function(Rect mask) onMaskUpdated;
  Rect mask;
  Mask({
    Key? key,
    required this.onMaskUpdated,
    required this.frameSize,
    required this.mask,
  }) : super(key: key);

  @override
  State<Mask> createState() => _MaskState();
}

class _MaskState extends State<Mask> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomPaint(
          size: widget.frameSize,
          painter: MaskPainter(mask: widget.mask),
        ),
        Positioned(
          top: widget.mask.top,
          left: widget.mask.left,
          child: MouseRegion(
            cursor: SystemMouseCursors.move,
            child: Listener(
              onPointerMove: (event) {
                Rect newMask = widget.mask.shift(event.localDelta);
                newMask = Offset(
                      newMask.topLeft.dx.clamp(0, widget.frameSize.width - newMask.width),
                      newMask.topLeft.dy.clamp(0, widget.frameSize.height - newMask.height),
                    ) &
                    newMask.size;

                setState(() {
                  widget.mask = newMask;
                });
                widget.onMaskUpdated(newMask);
              },
              child: Container(
                width: widget.mask.width,
                height: widget.mask.height,
                decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2)),
              ),
            ),
          ),
        ),
        Positioned(
          top: widget.mask.topLeft.dy - 15,
          left: widget.mask.topLeft.dx - 15,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
            child: Listener(
              onPointerMove: (event) {
                Size newSize = (widget.mask.size + -(event.localDelta));
                Offset newPos = (widget.mask.topLeft + event.localDelta);

                newPos = Offset(
                  newPos.dx.clamp(0, widget.frameSize.width),
                  newPos.dy.clamp(0, widget.frameSize.height),
                );
                newSize = Size(
                  newSize.width.clamp(0, widget.frameSize.width - newPos.dx),
                  newSize.height.clamp(0, widget.frameSize.height - newPos.dy),
                );
                setState(() {
                  widget.mask = newPos & newSize;
                });
                widget.onMaskUpdated(newPos & newSize);
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
        Positioned(
          top: widget.mask.bottomRight.dy - 15,
          left: widget.mask.bottomRight.dx - 15,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
            child: Listener(
              onPointerMove: (event) {
                Size newSize = (widget.mask.size + event.localDelta);

                newSize = Size(
                  newSize.width.clamp(0, widget.frameSize.width - widget.mask.topLeft.dx),
                  newSize.height.clamp(0, widget.frameSize.height - widget.mask.topLeft.dy),
                );

                setState(() {
                  widget.mask = widget.mask.topLeft & newSize;
                });
                widget.onMaskUpdated(widget.mask.topLeft & newSize);
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

class MaskPainter extends CustomPainter {
  final Rect mask;
  const MaskPainter({required this.mask});

  @override
  void paint(Canvas canvas, Size size) {
    Paint p = Paint()..color = Colors.black.withOpacity(.7);
    canvas.drawPath(
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
