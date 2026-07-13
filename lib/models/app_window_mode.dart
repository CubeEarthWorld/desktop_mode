enum AppWindowMode {
  auto,
  phonePortrait,
  phoneLandscape,
  fullExternal;

  static AppWindowMode fromWireName(String? value) =>
      AppWindowMode.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => AppWindowMode.auto,
      );
}
