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

//! no longer used
class Framebrowser extends StatefulWidget {
  final Function(NDIOutputFrame frame) onselectFrame;
  const Framebrowser({Key? key, required this.onselectFrame}) : super(key: key);

  @override
  _FramebrowserState createState() => _FramebrowserState();
}

//! no longer used
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
                                    child: NDIFrameThumbnail(file: fse),
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

/// The widget displaying only the rgba frame downscaled to 160x90 using a custom paint
class NDIFrameThumbnail extends StatefulWidget {
  final File file;
  const NDIFrameThumbnail({
    Key? key,
    required this.file,
  }) : super(key: key);

  @override
  State<NDIFrameThumbnail> createState() => _NDIFrameThumbnailState();
}

class _NDIFrameThumbnailState extends State<NDIFrameThumbnail> {
  late SavedInputFrame frame;
  @override
  void initState() {
    super.initState();
    // read the file and convert
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
    //initiate application directory and listener
    init();
  }

  //all contents of the application directory
  List<FileSystemEntity> appDirContents = [];
  //sorted directories of application directory
  List<Directory> appDirDirectorys = [];
  //all contents of the selected subdirectory
  List<FileSystemEntity> currentDirContents = [];

  init() async {
    // find the aopplication directory in documents
    final docDir = await getApplicationDocumentsDirectory();
    appDir = Directory(docDir.path + "/NDIScopes");

    // create if it doesn't exist and list all subderictories
    updateAppDir();

    // initiate listener to check for changes in the application directory
    appDir.watch(recursive: true).listen((event) {
      // fetch new subdirectories
      updateAppDir();
      // fetch frames in current subdirectory
      updateCurrentDir();
      setState(() {});
    });
    // if there are no subdirectories stop
    if (appDirDirectorys.isEmpty) return;
    // set the latest directory as the initial
    currentDir = appDirDirectorys.last;
    // fetch frames of initial subdirectory
    updateCurrentDir();
  }

  updateAppDir() {
    if (!appDir.existsSync()) appDir.createSync();
    // get all entities in application directory
    appDirContents = appDir.listSync(followLinks: false, recursive: false);
    // only consider subdirectories and ignore files
    appDirDirectorys = appDirContents.whereType<Directory>().toList();
    // sort all subdirectories by name (as int because the names are autogenerated to be the date of creation)
    appDirDirectorys.sort(
      (a, b) => int.parse(path.basename(a.path)).compareTo(
        int.parse(path.basename(b.path)),
      ),
    );
    // if we not jet have a directory selected and there are directories to select from set the latest directory as initial
    //if (currentDir == null && appDirDirectorys.isNotEmpty)
    currentDir = appDirDirectorys.last;
  }

  updateCurrentDir() async {
    // dont update if no dir selected
    if (currentDir == null) return;
    // fetch all entities, might cause exception if current dir now longer exists
    try {
      currentDirContents = currentDir!.listSync(recursive: false, followLinks: false);
    } catch (e) {
      currentDir = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cPrimary,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          if (appDirDirectorys.isNotEmpty && currentDir != null && appDirDirectorys.contains(currentDir))
            DropdownButton<Directory>(
              value: currentDir,
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
          if (appDirDirectorys.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                "No Frames",
                style: tSmall,
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: currentDirContents.length,
              // for every file system entry in the current dir
              itemBuilder: (context, index) {
                final fse = currentDirContents[index];
                // ignore files that don't end with ".ndis" and directories
                if (fse is File && path.extension(fse.path) == ".ndis") {
                  return DelayedCustomTooltip(
                    // get filename from path
                    path.basename(fse.path),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: InkWell(
                        onTap: () {
                          // read data from file and create frame and scopes
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
                            child: NDIFrameThumbnail(
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
