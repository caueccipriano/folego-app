import 'package:package_info_plus/package_info_plus.dart';

typedef PackageInfoLoader = Future<PackageInfo> Function();

class AppVersionInfo {
  const AppVersionInfo({
    required this.appName,
    required this.version,
    required this.buildNumber,
  });

  final String appName;
  final String version;
  final String buildNumber;

  String get versionLabel {
    final versionText = version.trim().isEmpty ? '—' : version.trim();
    final build = buildNumber.trim();

    if (build.isEmpty || build == '0') {
      return 'versão $versionText';
    }

    return 'versão $versionText · build $build';
  }

  static Future<AppVersionInfo> load({PackageInfoLoader? loader}) async {
    final packageInfo = await (loader ?? PackageInfo.fromPlatform)();

    return AppVersionInfo(
      appName: packageInfo.appName,
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
    );
  }
}
