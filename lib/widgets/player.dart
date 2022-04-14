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

/// Displays the incoming NDI frames aswell as a selected overlay
/// and all necessary buttons for source selection reference frame controls and mask controls
class FrameViewer extends StatefulWidget {
  final NDIOutputFrame? frame;
  final NDIOutputFrame? overlay;
  final double? overlayOpacity;
  final Function(int index) onSelectSource;
  final Function() onSaveFrame;
  final Function() onRemoveOverlay;
  final Function(OverlayMode mode, double splitPos, bool flipSplit) onOverlayChanged;
  final Function(Rect mask, bool active) onMaskUpdate;
  final Function(bool open) onToggleFrameBrowser;

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
    required this.onToggleFrameBrowser,
  }) : super(key: key);

  @override
  State<FrameViewer> createState() => _FrameViewerState();
}

class _FrameViewerState extends State<FrameViewer> {
  OverlayMode overlayMode = OverlayMode.splitVertical;
  double splitPos = 0.5;
  bool flipSplit = false;
  bool maskActive = false;
  bool frameBrowserOpen = false;
  late Rect mask;

  @override
  void initState() {
    super.initState();
    // initiate mask with default value
    mask = defaultMask();
  }

  // construct default rectangle for mask
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
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        //* button sidebar
        Column(
          mainAxisSize: MainAxisSize.max,
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
            //* colored container for all reference frame related buttons
            Container(
              // changes color when reference frame is selected
              color: widget.overlay != null ? cAccent : cPrimary,
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
                      //* split mode toggle button
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
                      //* flip overlay toogle button
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
                //* reset mask button
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
          ],
        ),
        //* frame viewer
        Expanded(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: FittedBox(
              fit: BoxFit.contain,
              child: ClipRect(
                child: Stack(
                  children: [
                    //* NDI SOURCE IMAGE + Overlay
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
                    //* Mask Overlay
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
                    //* Overlay slider vertical
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
                    //* Overlay slider horizontal
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
      //TODO: optional checkerboard behind frame with alpha
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
          Size overlaySize =
              Size(flipSplit ? overlay!.width * (1 - splitPos) : overlay!.width * splitPos, overlay!.height.toDouble());
          canvas.drawImageRect(
            overlay!,
            Offset(flipSplit ? overlay!.width * splitPos : 0, 0) & overlaySize,
            Offset(flipSplit ? overlay!.width * splitPos : 0, 0) & overlaySize,
            p,
          );
          break;
        // splits the overlay image horizontally based on split position and flip
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

/// the pop-up dialog shown when the select source button is pressed
///
/// callback returns the index of the selected source
/// updates the list of sources via ndi api
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
    updateSources();
  }

  updateSources() {
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
          //* refresh button
          DelayedCustomTooltip(
            "Refresh",
            child: IconButton(
              onPressed: (() {
                setState(() {
                  loading = true;
                });
                updateSources();
              }),
              color: Colors.white,
              iconSize: 25,
              icon: const Icon(Icons.refresh_sharp),
            ),
          ),
        ],
      ),
      children: [
        // display the loading indicator if loading
        if (loading)
          // necessary center because CircularProgressIndicator behaves weirdly if not in this arrangement of widgets
          const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
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
        //* List of source names
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
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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

/// displays the mask with control points
// ignore: must_be_immutable
class Mask extends StatefulWidget {
  final Size frameSize;
  final Function(Rect mask) onMaskUpdated;

  // mask can be changed from inside the widget and outside
  // not optimal
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
        //* paints the outside of the mask slightly black
        CustomPaint(
          size: widget.frameSize,
          painter: MaskPainter(mask: widget.mask),
        ),
        //* the actual rectangle with white borders that can be moved around
        Positioned(
          top: widget.mask.top,
          left: widget.mask.left,
          child: MouseRegion(
            cursor: SystemMouseCursors.move,
            child: Listener(
              //* listen for move events
              onPointerMove: (event) {
                Rect newMask = widget.mask.shift(event.localDelta);
                //* move the mask but not outside the frame
                newMask = Offset(
                      newMask.topLeft.dx.clamp(0, widget.frameSize.width - newMask.width),
                      newMask.topLeft.dy.clamp(0, widget.frameSize.height - newMask.height),
                    ) &
                    newMask.size;
                //* update the mask locally
                setState(() {
                  widget.mask = newMask;
                });
                //* send the mask to the api to mask the actual frames
                widget.onMaskUpdated(newMask);
              },
              //* the actual white border of the mask rectangle
              child: Container(
                width: widget.mask.width,
                height: widget.mask.height,
                decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2)),
              ),
            ),
          ),
        ),
        //* top left resize control
        Positioned(
          top: widget.mask.topLeft.dy - 15,
          left: widget.mask.topLeft.dx - 15,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
            child: Listener(
              //* listen for move events
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
        //* bottom right resize control
        Positioned(
          top: widget.mask.bottomRight.dy - 15,
          left: widget.mask.bottomRight.dx - 15,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
            child: Listener(
              //* listen for move events
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
