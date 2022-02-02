import 'package:flutter/material.dart';
import 'package:ndiscopes/models/colors.dart';
import 'package:ndiscopes/models/decorations.dart';
import 'package:ndiscopes/models/textstyles.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'dart:ui' as ui;

class Scopes extends StatefulWidget {
  final NDIFrame? frame;
  const Scopes({Key? key, required this.frame}) : super(key: key);

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
          Scope(img: widget.frame != null ? widget.frame!.iWF : null, title: "Luma Waveform"),
          Scope(img: widget.frame != null ? widget.frame!.iWFRgb : null, title: "RGB Waveform"),
          Scope(img: widget.frame != null ? widget.frame!.iWFParade : null, title: "RGB Parade"),
        ],
      ),
    );
  }
}

class Scope extends StatefulWidget {
  final String title;
  final ui.Image? img;
  const Scope({Key? key, required this.img, required this.title}) : super(key: key);

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
          height: expanded ? 295 : 0,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: 600,
              height: 295,
              child: Center(
                child: ClipRect(
                  child: CustomPaint(
                    painter: ScopePainter(img: widget.img),
                    size: const Size(600, 275),
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
  ScopePainter({required this.img});
  @override
  void paint(Canvas canvas, Size size) {
    Paint p = Paint();
    canvas.drawColor(Colors.black, BlendMode.srcATop);
    if (img != null) {
      canvas.drawImage(img!, const Offset(10, 10), p);
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
