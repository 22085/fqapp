import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// In-app self-update: the app checks `https://fqapp.sshdog.com/update.json`
/// on our own server (no GitHub login needed), downloads the matching split
/// APK itself and hands it to the system installer through the
/// `fqapp/app-update` channel (see `android/.../AppUpdatePlugin.kt`).
///
/// Manual only: nothing here runs at startup; the user taps 检查更新 in
/// Settings. The installed version and the device ABIs come from the
/// native side (PackageManager / `Build.SUPPORTED_ABIS`), so they can
/// never drift from the installed build and no new pub dependency is
/// needed for them.
class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  /// The version file the CI upload step rewrites on every build.
  static const _updateJsonUrl = 'https://fqapp.sshdog.com/update.json';

  static const _channel = MethodChannel('fqapp/app-update');

  /// Ask the server whether a newer build exists. A network or parse
  /// failure reports [AppUpdateStatus.failed], never a false "latest".
  Future<AppUpdateCheck> checkForUpdate() async {
    if (!Platform.isAndroid) {
      return const AppUpdateCheck.notSupported();
    }
    try {
      final Map<String, dynamic>? current =
          await _channel.invokeMapMethod<String, dynamic>('getCurrentInfo');
      final currentCode = current?['versionCode'];
      final currentName = current?['versionName'];
      final abis = current?['supportedAbis'];
      if (currentCode is! int ||
          currentName is! String ||
          abis is! List) {
        return const AppUpdateCheck.failed('无法读取当前版本');
      }
      final isArm64 = abis.any((abi) => abi == 'arm64-v8a');

      final http.Response response = await http
          .get(Uri.parse(_updateJsonUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        return const AppUpdateCheck.failed('更新服务器暂时不可用');
      }
      final Map<String, dynamic> json;
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return const AppUpdateCheck.failed('更新信息解析失败');
      }
      final remoteCode = json['versionCode'];
      final remoteName = json['versionName'];
      final arm64Url = json['arm64Url'];
      final armv7Url = json['armv7Url'];
      if (remoteCode is! int ||
          remoteName is! String ||
          arm64Url is! String ||
          armv7Url is! String) {
        return const AppUpdateCheck.failed('更新信息格式不对');
      }
      if (remoteCode <= currentCode) {
        return AppUpdateCheck.upToDate(currentName);
      }
      return AppUpdateCheck.available(
        AppUpdateInfo(
          versionCode: remoteCode,
          versionName: remoteName,
          downloadUrl: isArm64 ? arm64Url : armv7Url,
        ),
      );
    } on TimeoutException {
      return const AppUpdateCheck.failed('检查更新超时，请检查网络后重试');
    } catch (_) {
      return const AppUpdateCheck.failed('检查更新失败，请检查网络后重试');
    }
  }

  /// Stream-download the APK into the app's external files directory
  /// (covered by the FileProvider paths), reporting 0–1 progress. Any
  /// previously downloaded updater APK for this version is replaced.
  Future<File> downloadUpdate(
    AppUpdateInfo info, [
    void Function(double progress)? onProgress,
  ]) async {
    final Directory? external = await getExternalStorageDirectory();
    final Directory dir = external ?? await getTemporaryDirectory();
    final File file = File(
      '${dir.path}/fqapp-update-${info.versionCode}.apk',
    );
    if (await file.exists()) {
      await file.delete();
    }
    final http.Client client = http.Client();
    try {
      final http.StreamedResponse response = await client
          .send(http.Request('GET', Uri.parse(info.downloadUrl)))
          .timeout(const Duration(minutes: 10));
      if (response.statusCode != 200) {
        throw HttpException('下载失败（HTTP ${response.statusCode}）');
      }
      final int total = response.contentLength ?? -1;
      final IOSink sink = file.openWrite();
      var received = 0;
      await for (final List<int> chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (onProgress != null && total > 0) {
          onProgress(received / total);
        }
      }
      await sink.flush();
      await sink.close();
      return file;
    } finally {
      client.close();
    }
  }

  /// Open the system installer for [apk]. Returns `'ok'` when the
  /// installer was launched, `'needsPermission'` when the system needs
  /// "install unknown apps" allowed first (the native side already
  /// opened that settings page). Throws on a real failure.
  Future<String> installUpdate(File apk) async {
    final String? result = await _channel.invokeMethod<String>(
      'installApk',
      {'path': apk.path},
    );
    return result ?? 'failed';
  }
}

enum AppUpdateStatus { upToDate, available, failed, notSupported }

class AppUpdateCheck {
  const AppUpdateCheck._(
    this.status, {
    this.info,
    this.currentVersionName,
    this.reason,
  });

  const AppUpdateCheck.upToDate(String currentVersionName)
    : this._(AppUpdateStatus.upToDate, currentVersionName: currentVersionName);

  const AppUpdateCheck.available(AppUpdateInfo info)
    : this._(AppUpdateStatus.available, info: info);

  const AppUpdateCheck.failed(String reason)
    : this._(AppUpdateStatus.failed, reason: reason);

  const AppUpdateCheck.notSupported() : this._(AppUpdateStatus.notSupported);

  final AppUpdateStatus status;

  /// Set when [status] is [AppUpdateStatus.available].
  final AppUpdateInfo? info;

  /// Set when [status] is [AppUpdateStatus.upToDate].
  final String? currentVersionName;

  /// Set when [status] is [AppUpdateStatus.failed].
  final String? reason;
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.downloadUrl,
  });

  final int versionCode;
  final String versionName;

  /// The split APK matching this device's ABI.
  final String downloadUrl;
}
