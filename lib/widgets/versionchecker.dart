import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ndiscopes/config.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' as urll;

class VersionChecker extends StatefulWidget {
  const VersionChecker({
    Key? key,
  }) : super(key: key);

  @override
  State<VersionChecker> createState() => _VersionCheckerState();
}

class _VersionCheckerState extends State<VersionChecker> {
  static String host = "https://api.github.com";
  static String owner = "MindStudioOfficial";
  static String repo = "ndiscopes";
  static String pathToReleases = "/repos/$owner/$repo/releases";

  bool? isVersionOld;
  String? releaseURL;
  String? releaseVersion;

  @override
  void initState() {
    super.initState();
    checkCon().then((connected) {
      if (connected) {
        getVersion().then((suc) {
          if (suc) setState(() {});
        });
      }
    });
  }

  Future<bool> checkCon() async {
    final c = Completer<bool>();
    try {
      final result = await InternetAddress.lookup("example.com");
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        c.complete(true);
      }
    } on SocketException catch (_) {
      c.complete(false);
    }
    return c.future;
  }

  Future<bool> getVersion() async {
    final c = Completer<bool>();

    try {
      final res = await http.get(Uri.parse("$host$pathToReleases"));
      dynamic json = jsonDecode(res.body);
      if (json is! List) c.complete(false);
      if (json[0] is! Map<String, dynamic>) c.complete(false);
      final release = json[0];
      releaseURL = release["html_url"];
      releaseVersion = release["tag_name"];
      isVersionOld = parseVerisonString(releaseVersion!) > parseVerisonString(appConfig.version);
      c.complete(true);
    } on FormatException catch (e) {
      if (kDebugMode) {
        print(e);
      }
      c.complete(false);
    }

    return c.future;
  }

  int parseVerisonString(String verStr) {
    verStr = verStr.replaceAll(RegExp("[^0-9^.]"), "");

    List<String> verStrCells = verStr.split(".");
    List<int> verCells = List.generate(verStrCells.length, (index) => int.parse(verStrCells[index]));
    if (verCells.length == 3) return verCells[0] * 100000 + verCells[1] * 1000 + verCells[2];
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Text(
              "Version: ${appConfig.version}",
              style: TextStyle(color: Colors.white.withOpacity(.2)),
              overflow: TextOverflow.visible,
            ),
            if (releaseURL != null && releaseVersion != null && isVersionOld != null && isVersionOld!) ...[
              const SizedBox(width: 8),
              Ink(
                child: InkWell(
                  onTap: () {
                    urll.launchUrl(Uri.parse(releaseURL!));
                  },
                  child: Text(
                    "Update Available! - $releaseVersion",
                    style: const TextStyle(color: Colors.blue),
                  ),
                ),
              )
            ],
          ],
        ),
      ),
    );
  }
}
