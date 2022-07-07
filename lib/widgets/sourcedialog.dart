import 'package:flutter/material.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'package:ndiscopes/models/models.dart';
import 'package:ndiscopes/widgets/widgets.dart';

/// The pop-up dialog shown when the select source button is pressed
///
/// callback returns the index of the selected source
/// updates the list of sources via ndi api
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
    updateSources();
  }

  updateSources() {
    ndi.updateSoures().then((_) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
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
          if (loading)
            // necessary center because CircularProgressIndicator behaves weirdly if not in this arrangement of widgets
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    color: cHighlight,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          //* refresh button

          DelayedCustomTooltip(
            "Refresh",
            child: IconButton(
              onPressed: (() {
                setState(() {
                  loading = true;
                });
                updateSources();
              }),
              color: Colors.white,
              iconSize: 25,
              icon: const Icon(Icons.refresh_sharp),
            ),
          ),
        ],
      ),
      children: [
        // display the loading indicator if loading

        if (!loading && ndi.sources.isEmpty)
          Center(
            child: Text(
              "No Sources Found",
              style: tAccent,
            ),
          ),
        //* List of source names
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300, maxWidth: 300, minWidth: 300),
          child: ListView.builder(
            itemCount: ndi.sources.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                child: InkWell(
                  hoverColor: cHighlight.withOpacity(.75),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      ndi.sources[index].name,
                      style: tSmall,
                    ),
                  ),
                  onTap: () {
                    widget.onSelectSource(index);
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ),
        Center(
          child: InkWell(
            hoverColor: Colors.red.withOpacity(.75),
            child: Ink(
              color: Colors.red.withOpacity(.2),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  "Stop",
                  style: tSmall,
                ),
              ),
            ),
            onTap: () {
              widget.onSelectSource(-1);
              Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }
}
