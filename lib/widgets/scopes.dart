import 'package:flutter/material.dart';
import 'package:ndiscopes/models/decorations.dart';
import 'package:ndiscopes/models/textstyles.dart';
import 'package:ndiscopes/providers/frameprovider.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'dart:ui' as ui;
import 'package:ndiscopes/util/colorconversion.dart';
import 'package:ndiscopes/widgets/player.dart';

import 'package:provider/provider.dart';

//! no longer used
class Scopes extends StatelessWidget {
  final NDIOutputFrame? frame;
  final NDIOutputFrame? overlay;
  final OverlayMode overlayMode;
  final double splitPos;
  final double? overlayOpacity;
  final bool flipSplit;
  const Scopes({
    Key? key,
    required this.frame,
    this.overlay,
    this.overlayOpacity,
    required this.overlayMode,
    required this.splitPos,
    required this.flipSplit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        color: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Scope(
              img: frame?.iWF,
              title: "Luma Waveform",
              overlay: overlay != null ? overlay!.iWF : null,
              overlayOpacity: overlayOpacity,
              flipSplit: flipSplit,
              overlayMode: overlayMode,
              splitPos: splitPos,
            ),
            Scope(
              img: frame?.iWFRgb,
              title: "RGB Waveform",
              overlay: overlay != null ? overlay!.iWFRgb : null,
              overlayOpacity: overlayOpacity,
              flipSplit: flipSplit,
              overlayMode: overlayMode,
              splitPos: splitPos,
            ),
            Scope(
              img: frame?.iWFParade,
              title: "RGB Parade",
              overlay: overlay != null ? overlay!.iWFParade : null,
              overlayOpacity: overlayOpacity,
              flipSplit: flipSplit,
              overlayMode: overlayMode,
              splitPos: splitPos,
              isParade: true,
            ),
            VScope(
              img: frame?.iVScope,
              title: "Vectorscope",
              overlay: overlay != null ? overlay!.iVScope : null,
              overlayOpacity: overlayOpacity,
            ),
          ],
        ),
      ),
    );
  }
}

//! no longer used
class Scope extends StatefulWidget {
  final String title;
  final ui.Image? img;
  final ui.Image? overlay;
  final double? overlayOpacity;
  final double splitPos;
  final OverlayMode overlayMode;
  final bool flipSplit;
  final bool? isParade;
  const Scope({
    Key? key,
    required this.img,
    required this.title,
    this.overlay,
    this.overlayOpacity,
    required this.flipSplit,
    required this.overlayMode,
    required this.splitPos,
    this.isParade,
  }) : super(key: key);

  @override
  _ScopeState createState() => _ScopeState();
}

//! no longer used
class _ScopeState extends State<Scope> {
  bool expanded = true;
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (event) {
            setState(() {
              hover = true;
            });
          },
          onExit: (event) {
            setState(() {
              hover = false;
            });
          },
          child: GestureDetector(
            onTap: () {
              setState(() {
                expanded = !expanded;
              });
            },
            child: Container(
              height: 30,
              //color: hover ? cScopeTitleBackgroundHover : cScopeTitleBackground,
              decoration: hover ? dHoverGradient : dGradient,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 4,
                  ),
                  Icon(
                    expanded ? Icons.expand_more_sharp : Icons.expand_less_sharp,
                    color: Colors.white,
                    size: 20,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      child: Text(
                        widget.title,
                        style: tSmall,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedContainer(
          decoration: dBorder,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutQuad,
          height: expanded ? 296 : 0,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: 600,
              height: 296,
              child: FittedBox(
                fit: BoxFit.contain,
                child: ClipRect(
                  child: CustomPaint(
                    painter: ScopePainter(
                      img: widget.img,
                      opacity: widget.overlayOpacity,
                      overlay: widget.overlay,
                      flipSplit: widget.flipSplit,
                      overlayMode: widget.overlayMode,
                      splitPos: widget.splitPos,
                      isParade: widget.isParade,
                    ),
                    size: widget.img != null
                        ? Size(widget.img!.width + 20, widget.img!.height + 20)
                        : const Size(600, 275),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// paints a scope provided in [img]
///
/// overlays another scope [overlay] spliting it at [splitPos]
/// flips the sides if [flipSplit] is true
/// paints the overlay in thirds if [isParade] is true
class ScopePainter extends CustomPainter {
  final ui.Image? img;
  final ui.Image? overlay;
  final double? opacity;
  final double splitPos;
  final OverlayMode overlayMode;
  final bool flipSplit;
  final bool? isParade;

  const ScopePainter({
    required this.img,
    this.overlay,
    this.opacity,
    required this.flipSplit,
    required this.overlayMode,
    required this.splitPos,
    this.isParade,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // fills the background with black
    // doesn't account for canvas borders
    // surrounding this painter with cliprect is necessary
    canvas.drawColor(Colors.black, BlendMode.srcATop);
    Paint p = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    // if split horizontal put overlay with opacity in background
    if (overlay != null && overlayMode == OverlayMode.splitHorizontal) {
      // set opacity of the overlay
      p.color = Colors.black.withOpacity((opacity ?? 1).clamp(0, 1));

      p.colorFilter = const ColorFilter.matrix(
        // transform color of the background image
        // make alpha dependant of 3o% R 30% G 30% B 10% A
        // make color white
        <double>[
          // r g b a offset
          .33, .33, .33, 0, 0, // r
          .33, .33, .33, 0, 0, // g
          .33, .33, .33, 0, 0, // b
          0, 0, 0, 1, 0, // a
        ],
      );
      canvas.drawImage(overlay!, const Offset(10, 10), p);
    }
    // paint the scope image
    if (img != null) {
      Paint pI = Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;
      pI.colorFilter = const ColorFilter.matrix(
        <double>[
          1, 0, 0, 0, 0, // r
          0, 1, 0, 0, 0, // g
          0, 0, 1, 0, 0, // b
          0, 0, 0, 1, 0, // a
        ],
      );
      canvas.drawImage(img!, const Offset(10, 10), pI);
    }

    // paint the vertically split overlay on top of the image
    if (overlay != null && overlayMode == OverlayMode.splitVertical) {
      Paint pO = Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;
      // transform the color
      // makes alpha 100% to hide the image behind it to make split visible
      pO.colorFilter = const ColorFilter.matrix(
        <double>[
          // input
          // r g b a offset
          1, 0, 0, 0, 0, // r   |
          0, 1, 0, 0, 0, // g   | output
          0, 0, 1, 0, 0, // b   |
          0, 0, 0, 1, 0, // a |
        ],
      );

      // paint the overlay in a rectangle based on the split position and flipSplit
      if (isParade == null || !isParade!) {
        Rect srcRect = Offset(flipSplit ? overlay!.width * splitPos : 0, 0) &
            Size(flipSplit ? overlay!.width * (1 - splitPos) : overlay!.width * splitPos, overlay!.height.toDouble());
        Rect dstRect = Offset(flipSplit ? overlay!.width * splitPos : 0, 0) + const Offset(10, 10) &
            Size(flipSplit ? overlay!.width * (1 - splitPos) : overlay!.width * splitPos, overlay!.height.toDouble());
        canvas.drawRect(dstRect, Paint()..color = Colors.black);
        canvas.drawImageRect(
          overlay!,
          srcRect,
          dstRect,
          pO,
        );
        // if parade paint the overlay in thirds
      } else if (isParade!) {
        // draws three parts of the image next to each other all split at splitPos/3
        double third = overlay!.width.toDouble() / 3;
        Size s = Size(flipSplit ? third * (1 - splitPos) : third * splitPos, overlay!.height.toDouble());
        for (int i = 0; i < 3; i++) {
          Offset o = Offset(flipSplit ? i * third + third * splitPos : i * third, 0);
          canvas.drawRect(o + const Offset(10, 10) & s, Paint()..color = Colors.black);
          canvas.drawImageRect(overlay!, o & s, o + const Offset(10, 10) & s, pO);
        }
      }
    }

    // draw horizontal level lines in increments of 32
    p = Paint()..color = Colors.white.withOpacity(.3);
    for (int i = 0; i <= 8; i++) {
      double y = i * (img != null ? img!.height : 256) / 8;

      canvas.drawLine(Offset(10, y + 10), Offset(img != null ? img!.width + 10 : 590, y + 10), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

//! no longer used
class VScope extends StatefulWidget {
  final String title;
  final ui.Image? img;
  final ui.Image? overlay;
  final double? overlayOpacity;
  const VScope({Key? key, required this.img, required this.title, this.overlay, this.overlayOpacity}) : super(key: key);

  @override
  _VScopeState createState() => _VScopeState();
}

//! no longer used
class _VScopeState extends State<VScope> {
  bool expanded = true;
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (event) {
            setState(() {
              hover = true;
            });
          },
          onExit: (event) {
            setState(() {
              hover = false;
            });
          },
          child: GestureDetector(
            onTap: () {
              setState(() {
                expanded = !expanded;
              });
            },
            child: Container(
              height: 30,
              //color: hover ? cScopeTitleBackgroundHover : cScopeTitleBackground,
              decoration: hover ? dHoverGradient : dGradient,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 4,
                  ),
                  Icon(
                    expanded ? Icons.expand_more_sharp : Icons.expand_less_sharp,
                    color: Colors.white,
                    size: 20,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      child: Text(
                        widget.title,
                        style: tSmall,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedContainer(
          decoration: dBorder,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutQuad,
          height: expanded ? 600 : 0,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Stack(
              children: [
                SizedBox(
                  width: 600,
                  height: 600,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: ClipRect(
                      child: CustomPaint(
                        painter:
                            VScopePainter(img: widget.img, opacity: widget.overlayOpacity, overlay: widget.overlay),
                        size: widget.img != null
                            ? Size(widget.img!.width + 20, widget.img!.height + 20)
                            : const Size(276, 276),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// the colors at which to draw the squares on the vectorscope
///
/// once at 100% and once at 75% saturation
List<Color> scopeColors = [
  const Color.fromRGBO(210, 0, 0, 1),
  const Color.fromRGBO(210, 0, 210, 1),
  const Color.fromRGBO(0, 0, 210, 1),
  const Color.fromRGBO(0, 210, 210, 1),
  const Color.fromRGBO(0, 210, 0, 1),
  const Color.fromRGBO(210, 210, 0, 1),
];

/// The painter that draws the vectorscope [img] and [overlay] to gether with the colored squares and lines
class VScopePainter extends CustomPainter {
  ui.Image? img;
  ui.Image? overlay;
  double? opacity;

  VScopePainter({required this.img, this.overlay, this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    // fills the background with black
    // doesn't account for canvas borders
    // surrounding this painter with cliprect is necessary
    canvas.drawColor(Colors.black, BlendMode.srcATop);

    // save the topleft corner because it gets used very often
    Offset topleft = const Offset(10, 10);

    Paint pLine = Paint()
      // only draw the outlines with 30% opacity and 0.5px width
      ..style = PaintingStyle.stroke
      ..strokeWidth = .5
      ..isAntiAlias = true
      ..color = Colors.white.withOpacity(.3);
    // draw the
    canvas.drawLine(topleft + const Offset(128, 0), topleft + const Offset(128, 256), pLine);
    canvas.drawLine(topleft + const Offset(0, 128), topleft + const Offset(256, 128), pLine);
    // move to the center
    canvas.translate(138, 138);
    // rotate -34° around the center
    canvas.rotate(-2.164208);
    // draw the skintone line at -34° -90°
    canvas.drawLine(const Offset(0, 0), const Offset(128, 0), pLine);
    // rotate back
    canvas.rotate(2.164208);
    // reuse the paint for the colored rectangles
    pLine.strokeWidth = 1;
    // draw a rectangle for every color in scopeColors at its uv coordinate
    for (Color c in scopeColors) {
      // color at 100% saturation
      pLine.color = c.withOpacity(.9);
      // rotate to the vector of the uv coordiante so that the resulting rectangle gets also rotated
      canvas.rotate((uvFromRGB(pLine.color) - const Offset(128, 128)).direction);
      // draw the rectangle for the color
      canvas.drawRect(
        Offset((uvFromRGB(pLine.color) - const Offset(128, 128)).distance - 5, 0 - 5) & const Size(10, 10),
        pLine,
      );
      // interpolate between black and the color at 1-0.25 = 75% saturation
      pLine.color = Color.lerp(c.withOpacity(.7), Colors.black.withOpacity(.7), .25) ?? c;
      // draw the rectangle for the color at 75% saturation
      canvas.drawRect(
        Offset((uvFromRGB(pLine.color) - const Offset(128, 128)).distance - 2.5, 0 - 2.5) & const Size(5, 5),
        pLine,
      );
      // rotate back
      canvas.rotate(-(uvFromRGB(pLine.color) - const Offset(128, 128)).direction);
    }
    // move back to 0,0
    canvas.translate(-138, -138);

    // paint the overlay behind the image
    Paint p = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;
    if (overlay != null) {
      p.color = Colors.black.withOpacity((opacity ?? .5).clamp(0, 1));
      // transform the color to pink from green
      // alpha from green channel
      // r and b at 100%
      p.colorFilter = const ColorFilter.matrix(
        <double>[
          // r g b a offset
          0, 0, 0, 0, 255, // r
          0, .1, 0, 0, 0, // g
          0, 0, 0, 0, 255, // b
          0, 1, 0, 0, 0, // a
        ],
      );
      canvas.drawImage(overlay!, const Offset(10, 10), p);
    }

    if (img != null) {
      Paint p2 = Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;

      // transform image color
      // alpha from alpha
      p2.colorFilter = const ColorFilter.matrix(
        <double>[
          // r g b a offset
          1, 0, 0, 0, 0, // r
          0, 1, 0, 0, 0, // g
          0, 0, 1, 0, 0, // b
          0, 0, 0, 1, 0, // a
        ],
      );

      canvas.drawImage(img!, const Offset(10, 10), p2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class ScopeV2 extends StatefulWidget {
  final String title;
  final ui.Image? img;
  final ui.Image? ovl;
  final double overlayOpacity;
  final bool flipSplit;
  final OverlayMode overlayMode;
  final double splitPos;
  final bool isParade;
  const ScopeV2({
    Key? key,
    required this.flipSplit,
    required this.img,
    required this.isParade,
    required this.overlayMode,
    required this.overlayOpacity,
    this.ovl,
    required this.splitPos,
    required this.title,
  }) : super(key: key);

  @override
  State<ScopeV2> createState() => _ScopeV2State();
}

class _ScopeV2State extends State<ScopeV2> {
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 600 / 306,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(
                widget.title,
                style: tSmall,
              ),
            ),
            ClipRect(
              child: CustomPaint(
                painter: ScopePainter(
                  img: widget.img,
                  opacity: widget.overlayOpacity,
                  overlay: widget.ovl,
                  flipSplit: widget.flipSplit,
                  overlayMode: widget.overlayMode,
                  splitPos: widget.splitPos,
                  isParade: widget.isParade,
                ),
                size: widget.img != null
                    ? Size(
                        widget.img!.width + 20,
                        widget.img!.height + 20,
                      )
                    : const Size(600, 275),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VscopeV2 extends StatelessWidget {
  final String title;
  const VscopeV2({
    Key? key,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final frame = context.watch<Frame>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(4.0),
          child: Text(
            title,
            style: tSmall,
          ),
        ),
        AspectRatio(
          aspectRatio: 1,
          child: FittedBox(
            fit: BoxFit.contain,
            child: ClipRect(
              child: CustomPaint(
                painter: VScopePainter(
                    img: frame.imageFrame?.iVScope,
                    opacity: frame.overlayOpacity,
                    overlay: frame.overlayFrame?.iVScope),
                size: Size(
                  (frame.imageFrame?.iVScope.width ?? 256) + 20,
                  (frame.imageFrame?.iVScope.height ?? 256) + 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
