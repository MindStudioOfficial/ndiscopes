import 'package:flutter/material.dart';
import 'package:ndiscopes/models/colors.dart';
import 'package:ndiscopes/models/textstyles.dart';
import 'package:ndiscopes/providers/scopesettingsprovider.dart';
import 'package:provider/provider.dart';

class Settings extends StatelessWidget {
  final void Function(bool enabled) onToggleAudioOut;
  const Settings({Key? key, required this.onToggleAudioOut}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scopeSettings = context.watch<ScopeSettings>();
    return SingleChildScrollView(
      controller: ScrollController(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text("Vectorscope", style: tSmall.copyWith(fontSize: 18)),
          const SizedBox(height: 8),
          Text("Scale", style: tSmall),
          Slider(
            value: scopeSettings.vScopeScale,
            onChanged: (v) {
              scopeSettings.updateVScopeScale(v);
            },
            min: 0.5,
            max: 5,
            label: "Scale ${scopeSettings.vScopeScale}",
            divisions: 18,
            inactiveColor: cAccent,
            thumbColor: cHighlight,
            activeColor: cHighlight,
          ),
          Divider(color: cHighlight),
          const SizedBox(height: 8),
          Text("Waveforms", style: tSmall.copyWith(fontSize: 18)),
          CheckboxListTile(
            title: Text("Labels", style: tSmall),
            value: scopeSettings.showWFScale,
            onChanged: (v) {
              scopeSettings.toogleShowWVScale(show: v);
            },
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      scopeSettings.updateWVScaleType(WFScaleTypes.percentage);
                    },
                    child: Ink(
                      color: scopeSettings.wFScaleType == WFScaleTypes.percentage ? cHighlight : cAccent,
                      child: Center(
                          child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text("%", style: tBold.copyWith(fontSize: 15)),
                      )),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      scopeSettings.updateWVScaleType(WFScaleTypes.bits);
                    },
                    child: Ink(
                      color: scopeSettings.wFScaleType == WFScaleTypes.bits ? cHighlight : cAccent,
                      child: Center(
                          child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text("8Bit", style: tBold.copyWith(fontSize: 15)),
                      )),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: cHighlight),
          const SizedBox(height: 8),
          Text("Audio", style: tSmall.copyWith(fontSize: 18)),
          CheckboxListTile(
            title: Text("Meters", style: tSmall),
            value: scopeSettings.audioLevelEnabled,
            onChanged: (v) {
              scopeSettings.toggleAudioLevel(enable: v);
            },
          ),
          CheckboxListTile(
            title: Text("Output", style: tSmall),
            value: scopeSettings.audioOutputEnabled,
            onChanged: (v) {
              scopeSettings.toggleAudioOutput(enable: v);
              onToggleAudioOut(v ?? false);
            },
          ),
          /*CheckboxListTile(
            title: Text("Backdrop", style: tSmall),
            value: scopeSettings.enableWVBackdrop,
            onChanged: (v) {
              scopeSettings.toggleWVBackdrop(enable: v);
            },
          ),
          const SizedBox(height: 8),
          Text("Backdrop Opacity", style: tSmall),
          Slider(
            value: scopeSettings.backdropOpacity,
            onChanged: (v) {
              scopeSettings.updateBackdropOpacity(v);
            },
            min: 0,
            max: 1,
            label: "Opacity ${scopeSettings.backdropOpacity}",
            divisions: 20,
            inactiveColor: cAccent,
            thumbColor: cHighlight,
            activeColor: cHighlight,
          ),*/
          //Divider(color: cHighlight),
        ],
      ),
    );
  }
}
