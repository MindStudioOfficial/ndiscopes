import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';

late NDI ndi;

void main() {
  ndi = NDI();
  runApp(const Main());

  doWhenWindowReady(() {
    const initialSize = Size(1280, 720);
    appWindow.size = initialSize;
    appWindow.show();
  });
}

class Main extends StatelessWidget {
  const Main({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.grey.shade900,
        body: Center(
          child: TextButton(
            onPressed: () async {
              await ndi.updateSoures();
              print(ndi.sources);
            },
            child: const Text("Update Sources"),
          ),
        ),
      ),
    );
  }
}
