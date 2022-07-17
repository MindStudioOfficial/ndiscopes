import 'package:aligned_dialog/aligned_dialog.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:ndiscopes/models/models.dart';
import 'package:ndiscopes/providers/scopesettingsprovider.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'package:provider/provider.dart';

class ScopeSwitcher extends StatefulWidget {
  final int layoutIndex;
  const ScopeSwitcher({Key? key, required this.layoutIndex}) : super(key: key);

  @override
  State<ScopeSwitcher> createState() => _ScopeSwitcherState();
}

class _ScopeSwitcherState extends State<ScopeSwitcher> {
  bool _hasFocus = false;
  late FocusNode fn;

  @override
  void initState() {
    super.initState();
    fn = FocusNode();
    fn.addListener(focusListener);
  }

  @override
  void dispose() {
    fn.removeListener(focusListener);
    fn.dispose();
    super.dispose();
  }

  void focusListener() {
    setState(() {
      _hasFocus = fn.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scopesettings = context.watch<ScopeSettings>();

    return Row(
      children: [
        const Spacer(),
        DropdownButton<ScopeTypes>(
          dropdownColor: cDialogBackground,
          icon: const Icon(
            FluentIcons.caret_down_24_filled,
            size: 15,
          ),
          value: scopesettings.scopeLayout[widget.layoutIndex],
          underline: _hasFocus
              ? Container(
                  height: 2,
                  color: cFocused,
                )
              : Container(),
          iconSize: 15,
          isDense: true,
          style: tThin,
          focusColor: cFocused,
          focusNode: fn,
          items: List<DropdownMenuItem<ScopeTypes>>.generate(ScopeTypes.values.length, (index) {
            return DropdownMenuItem<ScopeTypes>(
              value: ScopeTypes.values[index],
              child: Center(
                child: Text(
                  scopeTypeNames[ScopeTypes.values[index]] ?? "???",
                  style: tSmall,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }),
          onChanged: (value) {
            // update the layout via the provider
            scopesettings.updateScopeLayout(widget.layoutIndex, value ?? ScopeTypes.luma);
            // get the updated set of needed scopes and update the ndi video isolate
            ndi.updateScopeTypes(scopesettings.scopeTypes);
          },
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: CustomMenu(
              type: scopesettings.scopeLayout[widget.layoutIndex],
            ),
          ),
        ),
      ],
    );
  }
}

class CustomMenu extends StatefulWidget {
  final ScopeTypes type;
  const CustomMenu({
    Key? key,
    required this.type,
  }) : super(key: key);

  @override
  State<CustomMenu> createState() => _CustomMenuState();
}

class _CustomMenuState extends State<CustomMenu> {
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        showAlignedDialog(
          barrierColor: Colors.transparent,
          avoidOverflow: true,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topRight,
          context: context,
          builder: (context) {
            final scopeSettings = context.watch<ScopeSettings>();
            return SizedBox(
              width: 150,
              child: Material(
                color: cDialogBackground,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: Text("Labels", style: tSmall),
                      value: scopeSettings.scaleEnabled[widget.type.index],
                      onChanged: (v) {
                        scopeSettings.toggleShowScale(widget.type, show: v);
                      },
                    ),
                    CheckboxListTile(
                      title: Text("Lines", style: tSmall),
                      value: scopeSettings.linesEnabled[widget.type.index],
                      onChanged: (v) {
                        scopeSettings.toggleShowLines(widget.type, show: v);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                scopeSettings.updateWVScaleType(widget.type, WFScaleTypes.percentage);
                              },
                              focusColor: cFocused,
                              child: Ink(
                                color: scopeSettings.scaleTypes[widget.type.index] == WFScaleTypes.percentage
                                    ? cHighlight
                                    : cAccent,
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
                                scopeSettings.updateWVScaleType(widget.type, WFScaleTypes.bits);
                              },
                              focusColor: cFocused,
                              child: Ink(
                                color: scopeSettings.scaleTypes[widget.type.index] == WFScaleTypes.bits
                                    ? cHighlight
                                    : cAccent,
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
                  ],
                ),
              ),
            );
          },
        );
      },
      style: bIconDefault.copyWith(
        fixedSize: MaterialStateProperty.all(const Size(20, 20)),
      ),
      child: const Icon(
        FluentIcons.more_horizontal_24_filled,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}
