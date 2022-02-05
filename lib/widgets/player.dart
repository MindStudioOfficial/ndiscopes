import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:ndiscopes/main.dart';
import 'package:ndiscopes/models/colors.dart';
import 'package:ndiscopes/models/textstyles.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'dart:ui' as ui;

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
  const FrameViewer({
    Key? key,
    required this.frame,
    required this.onSelectSource,
    this.overlay,
    this.overlayOpacity,
    required this.onSaveFrame,
    required this.onRemoveOverlay,
  }) : super(key: key);

  @override
  State<FrameViewer> createState() => _FrameViewerState();
}

class _FrameViewerState extends State<FrameViewer> {
  OverlayMode overlayMode = OverlayMode.splitVertical;
  double splitPos = 0.5;
  bool flipSplit = false;
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
                    if (widget.overlay != null && overlayMode == OverlayMode.splitVertical)
                      Positioned(
                        left: widget.overlay!.iRGBA.width * splitPos - 22.5,
                        top: widget.overlay!.iRGBA.height / 2 - 22.5,
                        child: Listener(
                          onPointerMove: (event) {
                            splitPos = (splitPos + event.localDelta.dx / widget.overlay!.iRGBA.width).clamp(0, 1);
                            setState(() {});
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
                            setState(() {});
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
        Align(
          alignment: Alignment.topLeft,
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
                Icons.collections_sharp,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.overlay != null) ...[
                Padding(
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
                if (overlayMode != OverlayMode.opacity) ...[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconButton(
                      iconSize: 25,
                      color: Colors.white,
                      onPressed: () {
                        overlayMode = overlayMode == OverlayMode.splitHorizontal
                            ? OverlayMode.splitVertical
                            : OverlayMode.splitHorizontal;
                        setState(() {});
                      },
                      icon: Icon(
                        overlayMode == OverlayMode.splitHorizontal
                            ? FluentIcons.split_vertical_28_regular
                            : FluentIcons.split_horizontal_28_regular,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconButton(
                      iconSize: 25,
                      color: Colors.white,
                      onPressed: () {
                        flipSplit = !flipSplit;
                        setState(() {});
                      },
                      icon: Icon(
                        overlayMode == OverlayMode.splitHorizontal
                            ? FluentIcons.flip_vertical_24_regular
                            : FluentIcons.flip_horizontal_24_regular,
                      ),
                    ),
                  ),
                ]
              ],
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  iconSize: 25,
                  color: Colors.white,
                  onPressed: () {
                    widget.onSaveFrame();
                  },
                  icon: const Icon(Icons.save_sharp),
                ),
              ),
            ],
          ),
        )
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
          canvas.drawImageRect(
            overlay!,
            Offset(flipSplit ? overlay!.width * splitPos : 0, 0) &
                Size(flipSplit ? overlay!.width * (1 - splitPos) : overlay!.width * splitPos,
                    overlay!.height.toDouble()),
            Offset(flipSplit ? overlay!.width * splitPos : 0, 0) &
                Size(flipSplit ? overlay!.width * (1 - splitPos) : overlay!.width * splitPos,
                    overlay!.height.toDouble()),
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
      setState(() {
        loading = false;
      });
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
          IconButton(
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
