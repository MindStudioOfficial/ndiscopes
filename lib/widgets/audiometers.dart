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

    return SizedBox(
      height: 200,
      child: CustomPaint(
        painter: AudioMeterPainter(audio),
        size: const Size(48, 200),
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

    double barWidth = size.width / (c + 1);
    double barPad = barWidth / (c + 1);

    Paint p = Paint()..color = cHighlight.withOpacity(.75);
    for (int i = 0; i < c; i++) {
      double dbU = dBUfromFloat(audio.levels[i]);

      double barHeight = (200 * ((dbU + 60) / 84)).clamp(0, 200);
      Offset topleft = Offset(i * barWidth + (i + 1) * barPad, 200 - barHeight);
      Size barSize = Size(barWidth, barHeight);

      canvas.drawRect(topleft & barSize, p);
    }
    double y = 57.143;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()..color = Colors.white.withOpacity(.75));
    canvas.drawLine(
        Offset(size.width / 2, 0), Offset(size.width / 2, size.height), Paint()..color = Colors.white.withOpacity(.5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
