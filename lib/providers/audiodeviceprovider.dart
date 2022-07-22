import 'package:flutter/material.dart';
import 'package:win32audio/win32audio.dart';

class AudioDevices extends ChangeNotifier {
  AudioDevices({
    List<AudioDevice>? audioDevices,
  }) {
    _audioDevices = audioDevices ?? _audioDevices;
  }
  List<AudioDevice> _audioDevices = [];

  List<AudioDevice> get audioDevices => _audioDevices;
  int get count => _audioDevices.length;

  Future<void> enumerateDevices() async {
    _audioDevices = await Audio.enumDevices(AudioDeviceType.output) ?? [];
    notifyListeners();
  }

  int? getAudioDeviceIDbyUID(String uid) {
    int id = _audioDevices.indexWhere((element) => element.name == uid);
    if (id == -1) return null;
    return id;
  }

  bool deviceWithNameExists(String name) {
    return _audioDevices.any((element) => element.name == name);
  }

  void updateAudioDevices(List<AudioDevice> devices) {
    _audioDevices = devices;
    notifyListeners();
  }
}
