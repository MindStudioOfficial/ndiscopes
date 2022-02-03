import 'package:flutter/material.dart';
import 'package:ndiscopes/main.dart';
import 'package:ndiscopes/models/colors.dart';
import 'package:ndiscopes/models/textstyles.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'dart:ui' as ui;

class FrameViewer extends StatelessWidget {
  final NDIOutputFrame? frame;
  final NDIOutputFrame? overlay;
  final double? overlayOpacity;
  final Function(int index) onSelectSource;
  const FrameViewer({Key? key, required this.frame, required this.onSelectSource, this.overlay, this.overlayOpacity})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: FittedBox(
              fit: BoxFit.contain,
              child: frame != null
                  ? CustomPaint(
                      painter: ImagePainter(
                        img: frame!.iRGBA,
                        overlay: overlay != null ? overlay!.iRGBA : null,
                        opacity: overlayOpacity,
                      ),
                      size: Size(
                        frame!.iRGBA.width.toDouble(),
                        frame!.iRGBA.height.toDouble(),
                      ),
                    )
                  : Container(
                      color: Colors.black,
                      width: 1920,
                      height: 1080,
                    ),
            ),
          ),
          IconButton(
            onPressed: () async {
              showDialog(
                context: context,
                builder: (context) {
                  return SourceSelectDialog(
                    onSelectSource: onSelectSource,
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
        ],
      ),
    );
  }
}

class ImagePainter extends CustomPainter {
  ui.Image? img;
  ui.Image? overlay;
  double? opacity;
  BlendMode? bm;
  ImagePainter({required this.img, this.bm, this.overlay, this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    Paint p = Paint()..blendMode = bm ?? BlendMode.srcOver;
    if (img != null) {
      canvas.drawImage(img!, Offset.zero, p);
    }
    if (overlay != null) {
      p.color = Colors.black.withOpacity(opacity ?? .5);
      canvas.drawImage(overlay!, Offset.zero, p);
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
