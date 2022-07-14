import 'package:flutter/material.dart';
import 'package:ndiscopes/models/textstyles.dart';
import 'package:ndiscopes/providers/providers.dart';
import 'package:ndiscopes/service/textures/textures.dart';
import 'dart:ui' as ui;
import 'package:ndiscopes/util/colorconversion.dart';
import 'package:ndiscopes/widgets/player.dart';
import 'package:ndiscopes/widgets/scopeswitcher.dart';
import 'package:provider/provider.dart';

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

class ScopeSelector extends StatelessWidget {
  final int layoutIndex;
  const ScopeSelector({
    Key? key,
    required this.layoutIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int imgId;
    int ovlId;
    bool parade = false;
    final scopeSettings = context.watch<ScopeSettings>();
    ScopeTypes type = scopeSettings.scopeLayout[layoutIndex];

    switch (type) {
      case ScopeTypes.luma:
        imgId = TextureIDs.texWF;
        ovlId = TextureIDs.texWFO;
        break;
      case ScopeTypes.parade:
        imgId = TextureIDs.texWFParade;
        ovlId = TextureIDs.texWFParadeO;
        parade = true;
        break;
      case ScopeTypes.rgb:
        imgId = TextureIDs.texWFRgb;
        ovlId = TextureIDs.texWFRgbO;
        break;
      case ScopeTypes.yuvparade:
        imgId = TextureIDs.texYUVParade;
        ovlId = TextureIDs.texYUVParadeO;
        break;
      case ScopeTypes.histogram:
        imgId = TextureIDs.texHistogram;
        ovlId = TextureIDs.texHistogramO;
        break;

      default:
        imgId = TextureIDs.texWF;
        ovlId = TextureIDs.texWFO;
        break;
    }
    return Scope(
      layoutIndex: layoutIndex,
      imgId: imgId,
      ovlId: ovlId,
      isParade: parade,
      title: scopeTypeNames[type] ?? "Unknown",
    );
  }
}

class Scope extends StatelessWidget {
  final String title;
  final bool isParade;
  final int imgId;
  final int ovlId;
  final int layoutIndex;

  const Scope({
    Key? key,
    required this.imgId,
    required this.ovlId,
    required this.isParade,
    required this.title,
    required this.layoutIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scopeSettings = context.watch<ScopeSettings>();
    final frame = context.watch<Frame>();

    bool texturesInitialized = frame.texturesInitialized;

    Widget imgw = texturesInitialized ? tr.widget(imgId) : Container();
    Widget ovlw = texturesInitialized ? tr.widget(ovlId) : Container();

    EdgeInsets scopePadding =
        scopeSettings.showWFScale ? const EdgeInsets.fromLTRB(20, 10, 0, 10) : const EdgeInsets.all(10);

    return AspectRatio(
      aspectRatio: 600 / 306,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 600,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Center(
                  child: ScopeSwitcher(
                    layoutIndex: layoutIndex,
                  ),
                ),
              ),
            ),
            RepaintBoundary(
              child: SizedBox(
                width: 600,
                height: 276,
                child: Stack(
                  children: [
                    Padding(
                      padding: scopePadding,
                      child: imgw,
                    ),
                    if (frame.overlayEnabled)
                      Padding(
                        padding: scopePadding,
                        child: isParade ? ParadeScopeSplit(child: ovlw) : ScopeSplit(child: ovlw),
                      ),
                    CustomPaint(
                      painter: ScopeLabelPainter(
                        scopeSettings: scopeSettings,
                      ),
                      size: const Size(600, 276),
                    ),
                  ],
                ),
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

class VScope extends StatelessWidget {
  final String title;
  final int imgId;
  final int ovlId;
  const VScope({
    Key? key,
    required this.imgId,
    required this.ovlId,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scopeSettings = context.watch<ScopeSettings>();
    final frame = context.watch<Frame>();

    bool texturesInitialized = frame.texturesInitialized;

    Widget imgw = texturesInitialized ? tr.widget(imgId) : Container();
    Widget ovlw = texturesInitialized ? tr.widget(ovlId) : Container();

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
        RepaintBoundary(
          child: AspectRatio(
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
                            width: 256,
                            height: 256,
                            child: Stack(
                              children: [
                                imgw,
                                if (frame.overlayEnabled) ovlw,
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
        Offset((uvFromRGB(pLine.color) - const Offset(128, 128)).distance + 5, 0 - 5) & const Size(10, 10),
        pLine,
      );
      // interpolate between black and the color at 1-0.25 = 75% saturation
      pLine.color = Color.lerp(c.withOpacity(.7), Colors.black.withOpacity(.7), .25) ?? c;
      // draw the rectangle for the color at 75% saturation
      canvas.drawRect(
        Offset((uvFromRGB(pLine.color) - const Offset(128, 128)).distance + 2.5, 0 - 2.5) & const Size(5, 5),
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

class ScopeSplit extends StatelessWidget {
  final Widget child;
  const ScopeSplit({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final frame = context.watch<Frame>();

    double width = 580;
    double height = 256;

    return SizedBox(
      width: width,
      height: height,
      child: Align(
        alignment: splitAlignment(frame.overlayMode, frame.flipSplit),
        child: ClipRect(
          child: Align(
            alignment: splitAlignment(frame.overlayMode, frame.flipSplit),
            widthFactor: frame.overlayMode == OverlayMode.splitVertical
                ? (frame.flipSplit ? 1 - frame.splitPos : frame.splitPos)
                : null,
            child: Container(
              color: frame.overlayMode == OverlayMode.splitVertical ? Colors.black : Colors.black.withOpacity(.3),
              width: width,
              height: height,
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

class ParadeScopeSplit extends StatelessWidget {
  final Widget child;
  const ParadeScopeSplit({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final frame = context.watch<Frame>();

    double width = 580;
    double height = 256;

    return ClipPath(
      clipper: ParadeClipper(
        flip: frame.flipSplit,
        height: height,
        width: width,
        splitPos: frame.splitPos,
        clip: frame.overlayMode == OverlayMode.splitVertical,
      ),
      child: Container(
        color: frame.overlayMode == OverlayMode.splitVertical ? Colors.black : Colors.black.withOpacity(.3),
        child: child,
      ),
    );
  }
}

class ParadeClipper extends CustomClipper<Path> {
  double splitPos;
  bool flip;
  double width;
  double height;
  bool clip;

  ParadeClipper({
    required this.splitPos,
    required this.flip,
    required this.height,
    required this.width,
    required this.clip,
  });

  @override
  Path getClip(Size size) {
    if (!clip) return Path()..addRect(Offset.zero & Size(width, height));
    Path p = Path();
    double thirdwidth = width / 3;
    Rect third = Offset.zero & Size(thirdwidth * (flip ? 1 - splitPos : splitPos), height);

    for (int i = 0; i < 3; i++) {
      p.addRect(third.translate(i * thirdwidth + (flip ? (splitPos) * thirdwidth : 0), 0));
    }
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper oldClipper) {
    return oldClipper is ParadeClipper &&
        (oldClipper.flip != flip || oldClipper.splitPos != splitPos || oldClipper.clip != clip);
  }
}
