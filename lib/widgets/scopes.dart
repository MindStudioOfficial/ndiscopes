import 'package:flutter/material.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'package:ndiscopes/widgets/player.dart';

class Scopes extends StatefulWidget {
  final NDIFrame? frame;
  const Scopes({Key? key, required this.frame}) : super(key: key);

  @override
  _ScopesState createState() => _ScopesState();
}

class _ScopesState extends State<Scopes> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 600,
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          if (widget.frame != null) ...[
            CustomPaint(
              painter: ImagePainter(img: widget.frame!.iWF),
              size: Size(widget.frame!.iWF.width.toDouble(), widget.frame!.iWF.height.toDouble()),
            ),
            CustomPaint(
              painter: ImagePainter(img: widget.frame!.iWFRgb),
              size: Size(widget.frame!.iWFRgb.width.toDouble(), widget.frame!.iWFRgb.height.toDouble()),
            ),
            CustomPaint(
              painter: ImagePainter(img: widget.frame!.iWFParade),
              size: Size(widget.frame!.iWFParade.width.toDouble(), widget.frame!.iWFParade.height.toDouble()),
            ),
          ]
        ],
      ),
    );
  }
}
