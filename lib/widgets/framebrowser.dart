import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:ndiscopes/models/colors.dart';
import 'package:ndiscopes/models/decorations.dart';
import 'package:ndiscopes/models/textstyles.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'package:ndiscopes/util/saveloadframe.dart';
import 'package:ndiscopes/widgets/customtooltip.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui;

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
                        child: InkWell(
                          //hoverColor: cDirHover,
                          onTap: () {
                            currentDir = fse;
                            updateDirContent();
                            setState(() {});
                          },
                          child: Ink(
                            //color: cDirBackground,
                            decoration: dAccentGradient,
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
                        child: InkWell(
                          //hoverColor: cDirHover,
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
                          child: Ink(
                            //color: cDirBackground,
                            decoration: dAccentGradient,
                            width: 96,
                            height: 96,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: NDIFrameThumnail(file: fse),
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
                  itemCount: dirContents.length,
                ),
              ),
            ]
          ],
        );
      },
    );
  }
}

class NDIFrameThumnail extends StatefulWidget {
  final File file;
  const NDIFrameThumnail({
    Key? key,
    required this.file,
  }) : super(key: key);

  @override
  State<NDIFrameThumnail> createState() => _NDIFrameThumnailState();
}

class _NDIFrameThumnailState extends State<NDIFrameThumnail> {
  late SavedInputFrame frame;
  @override
  void initState() {
    super.initState();
    frame = SavedInputFrame.fromJSON(jsonDecode(widget.file.readAsStringSync()));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return FutureBuilder<ui.Image?>(
        future: frame.thumbnailImage(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: FittedBox(
                fit: BoxFit.contain,
                child: CustomPaint(
                  size: const Size(160, 90),
                  painter: ThumbnailPainter(img: snapshot.data!),
                ),
              ),
            );
          } else {
            return const Icon(
              Icons.image_sharp,
              color: Colors.white,
              size: 35,
            );
          }
        },
      );
    });
  }
}

class ThumbnailPainter extends CustomPainter {
  final ui.Image img;
  ThumbnailPainter({required this.img});
  @override
  void paint(Canvas canvas, Size size) {
    //canvas.drawPaint(Paint()..color = Colors.black);
    canvas.drawImage(img, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class FrameBrowserV2 extends StatefulWidget {
  final Function(NDIOutputFrame frame) onSelectFrame;
  const FrameBrowserV2({Key? key, required this.onSelectFrame}) : super(key: key);

  @override
  State<FrameBrowserV2> createState() => _FrameBrowserV2State();
}

class _FrameBrowserV2State extends State<FrameBrowserV2> {
  Directory? currentDir;
  late Directory appDir;

  @override
  void initState() {
    super.initState();
    init();
  }

  List<FileSystemEntity> appDirContents = [];
  List<Directory> appDirDirectorys = [];
  List<FileSystemEntity> currentDirContents = [];

  init() async {
    final docDir = await getApplicationDocumentsDirectory();
    appDir = Directory(docDir.path + "/NDIScopes");
    updateAppDir();

    appDir.watch(recursive: true).listen((event) {
      updateAppDir();
      updateCurrentDir();
    });
    currentDir = appDirDirectorys.last;
    updateCurrentDir();
  }

  updateAppDir() {
    if (!appDir.existsSync()) appDir.createSync();
    appDirContents = appDir.listSync(followLinks: false, recursive: false);
    appDirDirectorys = appDirContents.whereType<Directory>().toList();
    appDirDirectorys.sort(
      (a, b) => int.parse(path.basename(a.path)).compareTo(
        int.parse(path.basename(b.path)),
      ),
    );
  }

  updateCurrentDir() async {
    if (currentDir == null) return;
    currentDirContents = currentDir!.listSync(recursive: false, followLinks: false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cPrimary,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          if (appDirDirectorys.isNotEmpty && currentDir != null)
            DropdownButton<Directory>(
              value: appDirDirectorys.contains(currentDir) ? currentDir : appDirDirectorys.last,
              items: appDirDirectorys
                  .map<DropdownMenuItem<Directory>>(
                    (d) => DropdownMenuItem<Directory>(
                      key: ValueKey(d),
                      value: d,
                      child: Text(
                        path.basename(d.path),
                        style: tSmall,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (d) {
                if (d != null) currentDir = d;
                updateCurrentDir();
                setState(() {});
              },
              dropdownColor: cPrimary,
            ),
          Expanded(
            child: ListView.builder(
              itemCount: currentDirContents.length,
              itemBuilder: (context, index) {
                final fse = currentDirContents[index];
                if (fse is File && path.extension(fse.path) == ".ndis") {
                  return DelayedCustomTooltip(
                    path.basename(fse.path),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: InkWell(
                        onTap: () {
                          SavedInputFrame.fromJSON(
                            jsonDecode(
                              fse.readAsStringSync(),
                            ),
                          ).convertToScopes(580, 256).then(
                            (frame) {
                              if (frame != null) widget.onSelectFrame(frame);
                            },
                          );
                        },
                        child: Ink(
                          width: 96,
                          height: 96,
                          child: Center(
                            child: NDIFrameThumnail(
                              file: fse,
                              key: ValueKey(fse),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                  return Container();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
