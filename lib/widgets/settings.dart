import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:ndiscopes/models/colors.dart';
import 'package:ndiscopes/models/textstyles.dart';
import 'package:ndiscopes/providers/audiodeviceprovider.dart';
import 'package:ndiscopes/providers/scopesettingsprovider.dart';
import 'package:provider/provider.dart';

class Settings extends StatefulWidget {
  final void Function(bool enabled) onToggleAudioOut;
  final void Function(int index) onAudioDeviceSelect;
  const Settings({
    Key? key,
    required this.onToggleAudioOut,
    required this.onAudioDeviceSelect,
  }) : super(key: key);

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final ScrollController _settingsScrollController = ScrollController();

  @override
  void dispose() {
    _settingsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scopeSettings = context.watch<ScopeSettings>();
    final audioDev = context.watch<AudioDevices>();
    return SingleChildScrollView(
      controller: _settingsScrollController,
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
              widget.onToggleAudioOut(v ?? false);
            },
          ),
          DropdownButton<int>(
            dropdownColor: cDialogBackground,
            isDense: false,
            icon: const Icon(
              FluentIcons.caret_down_24_filled,
              size: 15,
            ),
            focusColor: cFocused,
            style: tThin,
            isExpanded: true,
            itemHeight: 60,
            underline: Container(),
            value: audioDev.getAudioDeviceIDbyUID(scopeSettings.audioDeviceUID),
            items: List<DropdownMenuItem<int>>.generate(
              audioDev.count,
              (index) => DropdownMenuItem<int>(
                value: index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    audioDev.audioDevices[index].name,
                    style: tThin.copyWith(fontSize: 15),
                    textAlign: TextAlign.left,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ),
            ),
            onChanged: (val) {
              scopeSettings.updateAudioDeviceUID(audioDev.audioDevices[val ?? 0].id);
              widget.onAudioDeviceSelect((val != null ? val + 1 : null) ?? 0);
            },
          ),
        ],
      ),
    );
  }
}
