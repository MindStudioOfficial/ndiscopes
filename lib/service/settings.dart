import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ndiscopes/providers/scopesettingsprovider.dart';
import 'package:path_provider/path_provider.dart';

Future<ScopeSettings?> loadScopeSettings(void Function() onError) async {
  final supportDir = await getApplicationSupportDirectory();
  ScopeSettings s = ScopeSettings();
  File settingsFile = File(supportDir.path + "/config.json");
  if (!await settingsFile.exists()) {
    await settingsFile.create();
    await settingsFile.writeAsString(jsonEncode(s.toJson()));
    return s;
  }
  try {
    s = ScopeSettings.fromJson(jsonDecode(await settingsFile.readAsString()));
  } catch (e) {
    // _TypeError
    onError();
    return null;
  }

  return s;
}

Future<void> saveSettings(ScopeSettings settings) async {
  final supportDir = await getApplicationSupportDirectory();
  File settingsFile = File(supportDir.path + "/config.json");
  if (!await settingsFile.exists()) await settingsFile.create();

  await settingsFile.writeAsString(prettyJSON(settings.toJson()));
  return;
}

String prettyJSON(Map<String, dynamic> json) {
  JsonEncoder encoder = const JsonEncoder.withIndent("  ");
  return encoder.convert(json);
}
