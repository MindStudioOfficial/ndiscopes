import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:ndiscopes/models/colors.dart';
import 'package:ndiscopes/models/textstyles.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'package:ndiscopes/util/saveloadframe.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class Framebrowser extends StatefulWidget {
  final Function(NDIOutputFrame frame) onselectFrame;
  const Framebrowser({Key? key, required this.onselectFrame}) : super(key: key);

  @override
  _FramebrowserState createState() => _FramebrowserState();
}

class _FramebrowserState extends State<Framebrowser> {
  Directory? currentDir;
  StreamSubscription? fsWatcher;
  @override
  void initState() {
    super.initState();
    checkFolders(
      () {
        updateDirContent();
        setState(() {});
      },
    ).then((ss) => fsWatcher = ss);
    getApplicationDocumentsDirectory().then((docDir) {
      final appDir = Directory(docDir.path + "/NDIScopes");
      if (!appDir.existsSync()) appDir.createSync();
      currentDir = appDir;
      updateDirContent();
    });
  }

  List<FileSystemEntity> dirContents = [];

  void updateDirContent() {
    if (currentDir != null) {
      dirContents = currentDir!.listSync(followLinks: false, recursive: false);
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (fsWatcher != null) fsWatcher!.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            if (currentDir != null) ...[
              Container(
                color: cFrameBrowserHeader,
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (currentDir!.parent.existsSync()) {
                          currentDir = currentDir!.parent;
                          updateDirContent();
                          setState(() {});
                        }
                      },
                      color: Colors.white,
                      iconSize: 20,
                      icon: const Icon(FluentIcons.arrow_left_28_filled),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        path.prettyUri(currentDir!.uri.path),
                        style: tSmall,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight - 40,
                child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      FileSystemEntity fse = dirContents[index];
                      if (fse is Directory) {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: GestureDetector(
                            onTap: () {
                              currentDir = fse;
                              updateDirContent();
                              setState(() {});
                            },
                            child: Container(
                              color: cDirBackground,
                              width: 96,
                              height: 96,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.folder_sharp,
                                      color: Colors.white,
                                      size: 35,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        path.basename(fse.path),
                                        style: tSmall,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      if (fse is File && path.extension(fse.path) == ".ndis") {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: GestureDetector(
                            onTap: () {
                              SavedInputFrame.fromJSON(
                                jsonDecode(
                                  fse.readAsStringSync(),
                                ),
                              ).convertToScopes(580, 256).then(
                                (frame) {
                                  if (frame != null) widget.onselectFrame(frame);
                                },
                              );
                            },
                            child: Container(
                              color: cDirBackground,
                              width: 96,
                              height: 96,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.image_sharp,
                                      color: Colors.white,
                                      size: 35,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        path.basenameWithoutExtension(fse.path).split("_").join("\n"),
                                        style: tSmall,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      return Container();
                    },
                    itemCount: dirContents.length),
              ),
            ]
          ],
        );
      },
    );
  }
}
