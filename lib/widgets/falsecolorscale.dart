import 'package:flutter/material.dart';
import 'package:ndiscopes/models/models.dart';
import 'package:ndiscopes/providers/providers.dart';
import 'package:provider/provider.dart';

class FalseColorScale extends StatelessWidget {
  final ScrollController falseColorOuterScollController;
  final ScrollController falseColorInnerScollController;
  const FalseColorScale({
    Key? key,
    required this.falseColorInnerScollController,
    required this.falseColorOuterScollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final frame = context.watch<Frame>();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: frame.falseColorEnabled ? 75 : 0,
      child: SingleChildScrollView(
        controller: falseColorOuterScollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          width: 75,
          child: SingleChildScrollView(
            controller: falseColorInnerScollController,
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: ListView.builder(
                reverse: true,
                shrinkWrap: true,
                itemCount: falseColors.length,
                itemBuilder: (context, index) {
                  Color c = falseColors.keys.elementAt(index);
                  String label = falseColors.values.elementAt(index);

                  return Container(
                    color: c,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Text(
                          label,
                          style: tSmall.copyWith(color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
