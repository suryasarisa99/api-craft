class LaunchConfig {
  final String proxyPort;
  final String proxyHost;
  final dynamic preOption;
  final dynamic option;

  LaunchConfig({
    this.proxyPort = "8000",
    this.proxyHost = "127.0.0.1",
    this.option,
    this.preOption,
  });
}

class PreOption {
  final String label;
  final dynamic value;

  const PreOption({required this.label, required this.value});
}

typedef PreOptionsType = List<PreOption>;

abstract class Interceptor {
  String get name;
  String get description;
  List<String> get tags;

  void launch(LaunchConfig config);
  Future<List<dynamic>>? getOptions();
  dynamic getSubOptions(dynamic option);

  PreOptionsType getPreOptions() {
    return [];
  }
}
