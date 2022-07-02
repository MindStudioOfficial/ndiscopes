import 'package:flutter/material.dart';
import 'package:ndiscopes/models/textstyles.dart';
import 'package:ndiscopes/providers/frameprovider.dart';
import 'package:ndiscopes/providers/scopesettingsprovider.dart';
import 'package:ndiscopes/service/textures/textures.dart';
import 'dart:ui' as ui;
import 'package:ndiscopes/util/colorconversion.dart';
import 'package:ndiscopes/widgets/player.dart';
import 'package:provider/provider.dart';

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
  final ScopeSettings scopeSettings;

  const ScopePainter({
    required this.img,
    this.overlay,
    this.opacity,
    required this.flipSplit,
    required this.overlayMode,
    required this.splitPos,
    this.isParade,
    required this.scopeSettings,
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

    Offset topLeft = Offset(scopeSettings.showWFScale ? 20 : 10, 10);

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
      canvas.drawImage(overlay!, topLeft, p);
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
      canvas.drawImage(img!, topLeft, pI);
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
        Rect dstRect = Offset(flipSplit ? overlay!.width * splitPos : 0, 0) + topLeft &
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
          canvas.drawRect(o + topLeft & s, Paint()..color = Colors.black);
          canvas.drawImageRect(
            overlay!,
            o & s,
            o + topLeft & s,
            pO,
          );
        }
      }
    }

    // draw horizontal level depending on percentage or 8bit
    p = Paint()..color = Colors.white.withOpacity(.3);

    // calculate the amount of lines/labels
    int increments = 0;
    switch (scopeSettings.wFScaleType) {
      case WFScaleTypes.percentage:
        increments = 10;
        break;
      case WFScaleTypes.bits:
        increments = 8;
        break;
    }

    bool labels = scopeSettings.showWFScale;

    for (int i = 0; i <= increments; i++) {
      double y = i * (img != null ? img!.height : 256) / increments;
      if (labels) {
        String label = "";
        switch (scopeSettings.wFScaleType) {
          case WFScaleTypes.percentage:
            label = (100 - (100 / increments * i)).toInt().toString();
            break;
          case WFScaleTypes.bits:
            label = (256 - y).toInt().toString();
            break;
        }

        final pb = ui.ParagraphBuilder(
          ui.ParagraphStyle(
            fontSize: 11,
            textAlign: TextAlign.center,
            fontWeight: FontWeight.w100,
          ),
        )
          ..pushStyle(ui.TextStyle(color: Colors.grey))
          ..addText(label);

        final paragraph = pb.build();
        paragraph.layout(const ui.ParagraphConstraints(width: 18));

        canvas.drawParagraph(
          paragraph,
          Offset(1, y),
        );
      }
      canvas.drawLine(
        Offset(topLeft.dx, y + 10),
        Offset(img != null ? img!.width + topLeft.dx : size.width - (20 - topLeft.dx), y + 10),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
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
  double scopeScale;

  VScopePainter({required this.img, this.overlay, this.opacity, required this.scopeScale});

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

    canvas.scale(scopeScale);
    Offset imageRecenter = Offset(
      (size.width / scopeScale - (img?.width ?? overlay?.width ?? 256)) / 2,
      (size.height / scopeScale - (img?.height ?? overlay?.height ?? 256)) / 2,
    );
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
      canvas.drawImage(overlay!, imageRecenter, p);
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

      canvas.drawImage(img!, imageRecenter, p2);
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
  final bool isParade;
  const ScopeV2({
    Key? key,
    required this.img,
    required this.isParade,
    this.ovl,
    required this.title,
  }) : super(key: key);

  @override
  State<ScopeV2> createState() => _ScopeV2State();
}

class _ScopeV2State extends State<ScopeV2> {
  @override
  Widget build(BuildContext context) {
    final scopeSettings = context.watch<ScopeSettings>();
    final frame = context.watch<Frame>();
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
                  scopeSettings: scopeSettings,
                  img: widget.img,
                  opacity: frame.overlayOpacity,
                  overlay: widget.ovl,
                  flipSplit: frame.flipSplit,
                  overlayMode: frame.overlayMode,
                  splitPos: frame.splitPos,
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
    final scopeSettings = context.watch<ScopeSettings>();

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
                  overlay: frame.overlayFrame?.iVScope,
                  scopeScale: scopeSettings.vScopeScale,
                ),
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

class Scope extends StatelessWidget {
  final ScopeTypes type;
  const Scope({
    Key? key,
    required this.type,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final f = context.watch<Frame>();
    ui.Image? img;
    ui.Image? ovl;
    bool parade = false;
    switch (type) {
      case ScopeTypes.histogram:
        img = f.imageFrame?.iWF;
        ovl = f.overlayFrame?.iWF;
        break;
      case ScopeTypes.luma:
        img = f.imageFrame?.iWF;
        ovl = f.overlayFrame?.iWF;
        break;
      case ScopeTypes.parade:
        img = f.imageFrame?.iWFParade;
        ovl = f.overlayFrame?.iWFParade;
        parade = true;
        break;
      case ScopeTypes.rgb:
        img = f.imageFrame?.iWFRgb;
        ovl = f.overlayFrame?.iWFRgb;
        break;

      default:
        img = f.imageFrame?.iWF;
        ovl = f.overlayFrame?.iWF;
        break;
    }
    return ScopeV2(
      img: img,
      ovl: ovl,
      isParade: parade,
      title: scopeTypeNames[type] ?? "Unknown",
    );
  }
}

class ScopeSelector extends StatelessWidget {
  final ScopeTypes type;
  const ScopeSelector({
    Key? key,
    required this.type,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int imgId;
    int ovlId;
    bool parade = false;
    switch (type) {
      case ScopeTypes.histogram:
        imgId = texWF;
        ovlId = texWFO;
        break;
      case ScopeTypes.luma:
        imgId = texWF;
        ovlId = texWFO;
        break;
      case ScopeTypes.parade:
        imgId = texWFParade;
        ovlId = texWFParadeO;
        parade = true;
        break;
      case ScopeTypes.rgb:
        imgId = texWFRgb;
        ovlId = texWFRgbO;
        break;

      default:
        imgId = texWF;
        ovlId = texWFO;
        break;
    }
    return ScopeV3(
      imgId: imgId,
      ovlId: ovlId,
      isParade: parade,
      title: scopeTypeNames[type] ?? "Unknown",
    );
  }
}

class ScopeV3 extends StatelessWidget {
  final String title;
  final bool isParade;
  final int imgId;
  final int ovlId;

  const ScopeV3({
    Key? key,
    required this.imgId,
    required this.ovlId,
    required this.isParade,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget imgw = texturesInitialized ? tr.widget(imgId) : Container();
    Widget ovlw = texturesInitialized ? tr.widget(ovlId) : Container();
    final scopeSettings = context.watch<ScopeSettings>();
    EdgeInsets scopePadding =
        scopeSettings.showWFScale ? const EdgeInsets.fromLTRB(20, 10, 0, 10) : const EdgeInsets.all(10);
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
                title,
                style: tSmall,
              ),
            ),
            SizedBox(
              width: 600,
              height: 276,
              child: Stack(
                children: [
                  Padding(
                    padding: scopePadding,
                    child: imgw,
                  ),
                  Padding(
                    padding: scopePadding,
                    child: ovlw,
                  ),
                  CustomPaint(
                    painter: ScopeLabelPainter(
                      scopeSettings: scopeSettings,
                    ),
                    size: const Size(600, 276),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScopeLabelPainter extends CustomPainter {
  final bool? isParade;
  final ScopeSettings scopeSettings;

  const ScopeLabelPainter({
    this.isParade,
    required this.scopeSettings,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint p;

    // draw horizontal level depending on percentage or 8bit
    p = Paint()..color = Colors.white.withOpacity(.3);

    // calculate the amount of lines/labels
    int increments = 0;
    switch (scopeSettings.wFScaleType) {
      case WFScaleTypes.percentage:
        increments = 10;
        break;
      case WFScaleTypes.bits:
        increments = 8;
        break;
    }

    bool labels = scopeSettings.showWFScale;

    for (int i = 0; i <= increments; i++) {
      double y = i * 256 / increments;
      if (labels) {
        String label = "";
        switch (scopeSettings.wFScaleType) {
          case WFScaleTypes.percentage:
            label = (100 - (100 / increments * i)).toInt().toString();
            break;
          case WFScaleTypes.bits:
            label = (256 - y).toInt().toString();
            break;
        }

        final pb = ui.ParagraphBuilder(
          ui.ParagraphStyle(
            fontSize: 11,
            textAlign: TextAlign.center,
            fontWeight: FontWeight.w100,
          ),
        )
          ..pushStyle(ui.TextStyle(color: Colors.grey))
          ..addText(label);

        final paragraph = pb.build();
        paragraph.layout(const ui.ParagraphConstraints(width: 18));

        canvas.drawParagraph(
          paragraph,
          Offset(1, y),
        );
      }
      double leftOffset = scopeSettings.showWFScale ? 20 : 10;
      canvas.drawLine(
        Offset(leftOffset, y + 10),
        Offset(size.width - (20 - leftOffset), y + 10),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class VScopeV3 extends StatelessWidget {
  final String title;
  final int imgId;
  final int ovlId;
  const VScopeV3({
    Key? key,
    required this.imgId,
    required this.ovlId,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget imgw = texturesInitialized ? tr.widget(imgId) : Container();
    Widget ovlw = texturesInitialized ? tr.widget(ovlId) : Container();
    final scopeSettings = context.watch<ScopeSettings>();

    double offset = (276 - 256 * scopeSettings.vScopeScale) / 2;
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
            child: SizedBox(
              width: 276,
              height: 276,
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOutCubic,
                    left: offset,
                    top: offset,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      width: 256 * scopeSettings.vScopeScale,
                      height: 256 * scopeSettings.vScopeScale,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          child: Stack(
                            children: [
                              imgw,
                              ovlw,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  CustomPaint(
                    painter: VScopeOverlayPainter(scopeScale: scopeSettings.vScopeScale),
                    size: const Size(276, 276),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class VScopeOverlayPainter extends CustomPainter {
  double scopeScale;

  VScopeOverlayPainter({required this.scopeScale});

  @override
  void paint(Canvas canvas, Size size) {
    // fills the background with black
    // doesn't account for canvas borders
    // surrounding this painter with cliprect is necessary
    //canvas.drawColor(Colors.black, BlendMode.srcATop);

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

    canvas.scale(scopeScale);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is VScopeOverlayPainter && oldDelegate.scopeScale != scopeScale) return true;
    return false;
  }
}
