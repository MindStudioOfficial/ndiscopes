import 'package:flutter/material.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'dart:ui' as ui;

class FrameViewer extends StatelessWidget {
  final NDIFrame? frame;
  const FrameViewer({Key? key, required this.frame}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: FittedBox(
        fit: BoxFit.contain,
        child: frame != null
            ? CustomPaint(
                painter: ImagePainter(img: frame!.iRGBA),
                size: Size(frame!.iRGBA.width.toDouble(), frame!.iRGBA.height.toDouble()),
              )
            : Container(
                color: Colors.black,
                width: 1920,
                height: 1080,
              ),
      ),
    );
  }
}

class ImagePainter extends CustomPainter {
  ui.Image? img;
  BlendMode? bm;
  ImagePainter({required this.img, this.bm});

  @override
  void paint(Canvas canvas, Size size) {
    Paint p = Paint()..blendMode = bm ?? BlendMode.srcOver;
    if (img != null) {
      canvas.drawImage(img!, Offset.zero, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
