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

    return DropdownButton<ScopeTypes>(
      dropdownColor: cDialogBackground,
      icon: const Icon(
        FluentIcons.caret_down_24_filled,
        size: 15,
      ),
      value: scopesettings.scopeLayout[widget.layoutIndex],
      underline: _hasFocus
          ? Container(
              height: 2,
              color: cHighlight,
            )
          : Container(),
      iconSize: 15,
      isDense: true,
      style: tThin,
      focusColor: cHighlight,
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
    );
  }
}
