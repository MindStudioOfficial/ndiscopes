import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ndiscopes/models/colors.dart';
import 'package:ndiscopes/providers/audiolevelprovider.dart';
import 'package:ndiscopes/util/audioconversation.dart';
import 'package:provider/provider.dart';

class AudioMeters extends StatelessWidget {
  const AudioMeters({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioLevel>();

    return Expanded(
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 125,
          height: double.infinity,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: AudioMeterPainter(audio),
              //size: Size(50, double.infinity),
            ),
          ),
        ),
      ),
    );
  }
}

class AudioMeterPainter extends CustomPainter {
  AudioLevel audio;
  AudioMeterPainter(this.audio);

  @override
  void paint(Canvas canvas, Size size) {
    if (audio.levels.isEmpty) return;
    int c = audio.levels.length;
    double height = size.height - 16;

    double width = size.width - 30;

    double barWidth = width / (c + 1);
    double barPad = barWidth / (c + 1);

    Paint p = Paint()..color = cHighlight.withOpacity(.75);
    for (int i = 0; i < c; i++) {
      double dbU = dBUfromFloat(audio.levels[i]);

      double barHeight = (height * ((dbU + 60) / 84)).clamp(0, height);
      Offset topleft = Offset(i * barWidth + (i + 1) * barPad, height - barHeight + 8);
      Size barSize = Size(barWidth, barHeight);

      canvas.drawRect(topleft & barSize, p);
    }
    double y = height - (height * (60 / 84) - 8);
    canvas.drawLine(Offset(0, y), Offset(width, y), Paint()..color = Colors.white.withOpacity(.75));
    canvas.drawLine(Offset(width, 8), Offset(width, size.height - 8), Paint()..color = Colors.white.withOpacity(.5));

    for (int dBuVal in dBus) {
      double yPos = height - (height * ((dBuVal + 60) / 84));
      final p = ui.ParagraphBuilder(
        ui.ParagraphStyle(fontSize: 11, textAlign: TextAlign.left, fontWeight: FontWeight.w100),
      )
        ..pushStyle(ui.TextStyle(color: Colors.white))
        ..addText((dBuVal > 0 ? "+" : "") + dBuVal.toString());
      if (dBuVal == 0) p.addText("dBu");
      final para = p.build();
      para.layout(const ui.ParagraphConstraints(width: 25));
      canvas.drawParagraph(para, Offset(width + 4, yPos));
    }
  }

  List<int> dBus = [24, 18, 10, 4, 0, -8, -16, -20, -40, -60];

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
