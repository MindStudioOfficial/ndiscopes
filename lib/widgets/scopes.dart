import 'package:flutter/material.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';

class Scopes extends StatefulWidget {
  final NDIFrame? frame;
  const Scopes({Key? key, required this.frame}) : super(key: key);

  @override
  _ScopesState createState() => _ScopesState();
}

class _ScopesState extends State<Scopes> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      color: const Color.fromARGB(255, 165, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: const [],
      ),
    );
  }
}
