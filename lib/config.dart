final appConfig = AppConfig();

class AppConfig {
  static final AppConfig _appConfig = AppConfig._internal();

  factory AppConfig() {
    return _appConfig;
  }

  AppConfig._internal();
  String get version => "v0.6.1-beta"; //! TODO: Update version each new release!!! Also Update Readme
  String get minGPUDriver => "511.23";
  int get minMajorCC => 3;
  int get minMinorCC => 5;
}
