import 'package:flutter/material.dart';
import 'package:ndiscopes/models/decorations.dart';
import 'package:ndiscopes/models/textstyles.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'dart:ui' as ui;
import 'package:ndiscopes/util/colorconversion.dart';
import 'package:ndiscopes/widgets/player.dart';

/*
class Scopes extends StatefulWidget {
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
  _ScopesState createState() => _ScopesState();
}*/

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

class ScopePainter extends CustomPainter {
  ui.Image? img;
  ui.Image? overlay;
  double? opacity;
  double splitPos;
  OverlayMode overlayMode;
  bool flipSplit;
  bool? isParade;
  ScopePainter({
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
    canvas.drawColor(Colors.black, BlendMode.srcATop);
    Paint p = Paint();
    if (overlay != null && overlayMode == OverlayMode.splitHorizontal) {
      p.color = Colors.black.withOpacity((opacity ?? .2).clamp(0, 1));
      p.colorFilter =
          const ColorFilter.matrix(<double>[0, 1, 0, 0, 255, 0, 0, 1, 0, 255, 1, 0, 0, 0, 255, .2, .2, .2, 0, 0]);
      canvas.drawImage(overlay!, const Offset(10, 10), p);
    }

    if (img != null) {
      Paint p2 = Paint();
      /*if (overlay != null) {
        p2.colorFilter = const ColorFilter.matrix(<double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 0]);
      }*/
      canvas.drawImage(img!, const Offset(10, 10), p2);
    }

    if (overlay != null) {
      Paint pO = Paint()..color = Colors.white;
      pO.colorFilter = const ColorFilter.matrix(<double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 255]);

      if (overlayMode == OverlayMode.splitVertical) {
        if (isParade == null) {
          Rect srcRect = Offset(flipSplit ? overlay!.width * splitPos : 0, 0) &
              Size(flipSplit ? overlay!.width * (1 - splitPos) : overlay!.width * splitPos, overlay!.height.toDouble());
          Rect dstRect = Offset(flipSplit ? overlay!.width * splitPos : 0, 0) + const Offset(10, 10) &
              Size(flipSplit ? overlay!.width * (1 - splitPos) : overlay!.width * splitPos, overlay!.height.toDouble());
          canvas.drawImageRect(
            overlay!,
            srcRect,
            dstRect,
            pO,
          );
        } else if (isParade!) {
          double third = overlay!.width.toDouble() / 3;
          Size s = Size(flipSplit ? third * (1 - splitPos) : third * splitPos, overlay!.height.toDouble());
          for (int i = 0; i < 3; i++) {
            Offset o = Offset(flipSplit ? i * third + third * splitPos : i * third, 0);
            canvas.drawImageRect(overlay!, o & s, o + const Offset(10, 10) & s, pO);
          }
        }
      }
    }

    p = Paint()..color = Colors.white.withOpacity(.3);
    for (int i = 0; i <= 8; i++) {
      double y = i * (img != null ? img!.height : 256) / 8;

      canvas.drawLine(Offset(10, y + 10), Offset(img != null ? img!.width + 10 : 580, y + 10), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class VScope extends StatefulWidget {
  final String title;
  final ui.Image? img;
  final ui.Image? overlay;
  final double? overlayOpacity;
  const VScope({Key? key, required this.img, required this.title, this.overlay, this.overlayOpacity}) : super(key: key);

  @override
  _VScopeState createState() => _VScopeState();
}

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

List<Color> scopeColors = [
  const Color.fromRGBO(210, 0, 0, 1),
  const Color.fromRGBO(210, 0, 210, 1),
  const Color.fromRGBO(0, 0, 210, 1),
  const Color.fromRGBO(0, 210, 210, 1),
  const Color.fromRGBO(0, 210, 0, 1),
  const Color.fromRGBO(210, 210, 0, 1),
];

class VScopePainter extends CustomPainter {
  ui.Image? img;
  ui.Image? overlay;
  double? opacity;
  VScopePainter({required this.img, this.overlay, this.opacity});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(Colors.black, BlendMode.srcATop);
    Offset topleft = const Offset(10, 10);
    Paint pi = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .3
      ..isAntiAlias = true
      ..color = Colors.white.withOpacity(.3);

    //canvas.drawCircle(const Offset(128, 128) + topleft, 128, pi);
    canvas.drawLine(topleft + const Offset(128, 0), topleft + const Offset(128, 256), pi);
    canvas.drawLine(topleft + const Offset(0, 128), topleft + const Offset(256, 128), pi);

    canvas.translate(138, 138);

    canvas.rotate(-2.164208);
    canvas.drawLine(const Offset(0, 0), const Offset(128, 0), pi);
    canvas.rotate(2.164208);

    pi.strokeWidth = 1;
    for (Color c in scopeColors) {
      pi.color = c.withOpacity(.9);

      canvas.rotate((uvFromRGB(pi.color) - const Offset(128, 128)).direction);
      canvas.drawRect(
          Offset((uvFromRGB(pi.color) - const Offset(128, 128)).distance - 5, 0 - 5) & const Size(10, 10), pi);
      canvas.rotate(-(uvFromRGB(pi.color) - const Offset(128, 128)).direction);
    }
    for (Color c in scopeColors) {
      pi.color = Color.lerp(c.withOpacity(.7), Colors.black.withOpacity(.7), .25) ?? c;

      canvas.rotate((uvFromRGB(pi.color) - const Offset(128, 128)).direction);
      canvas.drawRect(
          Offset((uvFromRGB(pi.color) - const Offset(128, 128)).distance - 2.5, 0 - 2.5) & const Size(5, 5), pi);
      canvas.rotate(-(uvFromRGB(pi.color) - const Offset(128, 128)).direction);
    }
    canvas.translate(-138, -138);

    Paint p = Paint();
    if (overlay != null) {
      p.color = Colors.black.withOpacity((opacity ?? .5).clamp(0, 1));

      p.colorFilter =
          const ColorFilter.matrix(<double>[0, 0, 0, 0, 255, 0, .1, 0, 0, 0, 0, 0, 0, 0, 255, 0, 1, 0, 0, 0]);
      canvas.drawImage(overlay!, const Offset(10, 10), p);
    }

    if (img != null) {
      Paint p2 = Paint();
      if (overlay != null) {
        p2.colorFilter = const ColorFilter.matrix(<double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]);
      }
      canvas.drawImage(img!, const Offset(10, 10), p2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class ScopeV2 extends StatelessWidget {
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
    required this.ovl,
    required this.splitPos,
    required this.title,
  }) : super(key: key);

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
                title,
                style: tSmall,
              ),
            ),
            ClipRect(
              child: CustomPaint(
                painter: ScopePainter(
                  img: img,
                  opacity: overlayOpacity,
                  overlay: ovl,
                  flipSplit: flipSplit,
                  overlayMode: overlayMode,
                  splitPos: splitPos,
                  isParade: isParade,
                ),
                size: img != null
                    ? Size(
                        img!.width + 20,
                        img!.height + 20,
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
  final ui.Image? img;
  final ui.Image? ovl;
  final String title;
  final double overlayOpacity;
  const VscopeV2({
    Key? key,
    required this.img,
    required this.ovl,
    required this.title,
    required this.overlayOpacity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
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
                painter: VScopePainter(img: img, opacity: overlayOpacity, overlay: ovl),
                size: img != null ? Size(img!.width + 20, img!.height + 20) : const Size(276, 276),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
