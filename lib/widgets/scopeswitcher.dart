import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:ndiscopes/models/models.dart';
import 'package:ndiscopes/providers/scopesettingsprovider.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'package:provider/provider.dart';

class ScopeSwitcher extends StatelessWidget {
  final int layoutIndex;
  const ScopeSwitcher({Key? key, required this.layoutIndex}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scopesettings = context.watch<ScopeSettings>();

    return DropdownButton<ScopeTypes>(
      dropdownColor: cDialogBackground,
      icon: const Icon(
        FluentIcons.caret_down_24_filled,
        size: 15,
      ),
      value: scopesettings.scopeLayout[layoutIndex],
      underline: Container(),
      iconSize: 15,
      isDense: true,
      style: tThin,
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
        scopesettings.updateScopeLayout(layoutIndex, value ?? ScopeTypes.luma);
        // get the updated set of needed scopes and update the ndi video isolate
        ndi.updateScopeTypes(scopesettings.scopeTypes);
      },
    );
  }
}
