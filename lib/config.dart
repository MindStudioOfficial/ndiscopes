class AppConfig {
  static final AppConfig _appConfig = AppConfig._internal();

  factory AppConfig() {
    return _appConfig;
  }

  AppConfig._internal();

  String get minGPUDriver => "511.23";
  int get minMajorCC => 3;
  int get minMinorCC => 5;
}
