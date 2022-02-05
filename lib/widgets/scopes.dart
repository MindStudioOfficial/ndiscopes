import 'package:flutter/material.dart';
import 'package:ndiscopes/models/colors.dart';
import 'package:ndiscopes/models/decorations.dart';
import 'package:ndiscopes/models/textstyles.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'dart:ui' as ui;

class Scopes extends StatefulWidget {
  final NDIOutputFrame? frame;
  final NDIOutputFrame? overlay;
  final double? overlayOpacity;
  const Scopes({Key? key, required this.frame, this.overlay, this.overlayOpacity}) : super(key: key);

  @override
  _ScopesState createState() => _ScopesState();
}

class _ScopesState extends State<Scopes> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Scope(
            img: widget.frame != null ? widget.frame!.iWF : null,
            title: "Luma Waveform",
            overlay: widget.overlay != null ? widget.overlay!.iWF : null,
            overlayOpacity: widget.overlayOpacity,
          ),
          Scope(
            img: widget.frame != null ? widget.frame!.iWFRgb : null,
            title: "RGB Waveform",
            overlay: widget.overlay != null ? widget.overlay!.iWFRgb : null,
            overlayOpacity: widget.overlayOpacity,
          ),
          Scope(
            img: widget.frame != null ? widget.frame!.iWFParade : null,
            title: "RGB Parade",
            overlay: widget.overlay != null ? widget.overlay!.iWFParade : null,
            overlayOpacity: widget.overlayOpacity,
          ),
          VScope(
            img: widget.frame != null ? widget.frame!.iVScope : null,
            title: "Vectorscope",
            overlay: widget.overlay != null ? widget.overlay!.iVScope : null,
            overlayOpacity: widget.overlayOpacity,
          ),
        ],
      ),
    );
  }
}

class Scope extends StatefulWidget {
  final String title;
  final ui.Image? img;
  final ui.Image? overlay;
  final double? overlayOpacity;
  const Scope({Key? key, required this.img, required this.title, this.overlay, this.overlayOpacity}) : super(key: key);

  @override
  _ScopeState createState() => _ScopeState();
}

class _ScopeState extends State<Scope> {
  bool expanded = true;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              expanded = !expanded;
            });
          },
          child: Container(
            height: 30,
            color: cScopeTitleBackground,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
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
        AnimatedContainer(
          decoration: dBorderDecoration,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutQuad,
          height: expanded ? 296 : 0,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: 600,
              height: 296,
              child: Center(
                child: ClipRect(
                  child: CustomPaint(
                    painter: ScopePainter(img: widget.img, opacity: widget.overlayOpacity, overlay: widget.overlay),
                    size: const Size(600, 276),
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
  ScopePainter({required this.img, this.overlay, this.opacity});
  @override
  void paint(Canvas canvas, Size size) {
    Paint p = Paint();
    canvas.drawColor(Colors.black, BlendMode.srcATop);

    if (overlay != null) {
      p.color = Colors.black.withOpacity((opacity ?? .2).clamp(0, 1));
      p.colorFilter =
          const ColorFilter.matrix(<double>[0, 1, 0, 0, 255, 0, 0, 1, 0, 255, 1, 0, 0, 0, 255, .2, .2, .2, 0, 0]);
      canvas.drawImage(overlay!, const Offset(10, 10), p);
    }

    if (img != null) {
      Paint p2 = Paint();
      p2.colorFilter = const ColorFilter.matrix(<double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 0]);
      canvas.drawImage(img!, const Offset(10, 10), p2);
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
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              expanded = !expanded;
            });
          },
          child: Container(
            height: 30,
            color: cScopeTitleBackground,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
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
        AnimatedContainer(
          decoration: dBorderDecoration,
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
                        size: const Size(276, 276),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -20,
                  top: 5,
                  child: Image.asset(
                    "graphics/vscope.png",
                    color: Colors.white.withOpacity(.3),
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class VScopePainter extends CustomPainter {
  ui.Image? img;
  ui.Image? overlay;
  double? opacity;
  VScopePainter({required this.img, this.overlay, this.opacity});
  @override
  void paint(Canvas canvas, Size size) {
    Paint p = Paint();
    canvas.drawColor(Colors.black, BlendMode.srcATop);
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
