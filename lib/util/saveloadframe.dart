import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ndiscopes/util/datetimetostring.dart';

Future<void> saveInputFrame(SavedInputFrame frame) async {
  Directory docDir = await getApplicationDocumentsDirectory();
  Directory appDir = Directory(docDir.path + "/NDIScopes");
  if (!(await appDir.exists())) {
    await appDir.create();
  }
  Directory saveDir = Directory(appDir.path + "/${frame.timestamp.toDateShortString()}");
  if (!(await saveDir.exists())) {
    await saveDir.create();
  }
  File frameFile = File("${saveDir.path}/${frame.timestamp.toDateTimeShortString()}.ndis");
  await frameFile.writeAsString(jsonEncode(frame.toJSON()));
}

Future<StreamSubscription> checkFolders(void Function() onFolderChanged) async {
  Directory docDir = await getApplicationDocumentsDirectory();
  Directory appDir = Directory(docDir.path + "/NDIScopes");
  if (!(await appDir.exists())) {
    await appDir.create();
  }
  final ss = appDir.watch(recursive: false).listen((event) {
    onFolderChanged();
  });
  return ss;
}
