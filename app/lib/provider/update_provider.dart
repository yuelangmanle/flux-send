import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

const fluxGitHubRepositoryUrl = 'https://github.com/yuelangmanle/flux-send';
const fluxLatestReleaseApiUrl = 'https://api.github.com/repos/yuelangmanle/flux-send/releases/latest';

enum FluxUpdatePlatform { android, macOS, windows, linux, unsupported }

class FluxSemanticVersion implements Comparable<FluxSemanticVersion> {
  final int major;
  final int minor;
  final int patch;

  const FluxSemanticVersion(this.major, this.minor, this.patch);

  factory FluxSemanticVersion.parse(String value) {
    final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$').firstMatch(value.trim());
    if (match == null) {
      throw FormatException('无法识别版本号：$value');
    }

    return FluxSemanticVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  @override
  int compareTo(FluxSemanticVersion other) {
    final majorComparison = major.compareTo(other.major);
    if (majorComparison != 0) {
      return majorComparison;
    }

    final minorComparison = minor.compareTo(other.minor);
    if (minorComparison != 0) {
      return minorComparison;
    }

    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}

class FluxReleaseAsset {
  final String name;
  final Uri downloadUri;

  const FluxReleaseAsset({required this.name, required this.downloadUri});
}

class FluxRelease {
  final FluxSemanticVersion version;
  final Uri releasePageUri;
  final List<FluxReleaseAsset> assets;

  const FluxRelease({
    required this.version,
    required this.releasePageUri,
    required this.assets,
  });

  factory FluxRelease.fromGitHubJson(Map<String, dynamic> json) {
    if (json['draft'] == true || json['prerelease'] == true) {
      throw const FormatException('GitHub 返回了非正式版本');
    }

    final tag = json['tag_name'];
    final releasePage = json['html_url'];
    final rawAssets = json['assets'];
    if (tag is! String || releasePage is! String || rawAssets is! List) {
      throw const FormatException('GitHub 发布信息格式不完整');
    }

    final assets = <FluxReleaseAsset>[];
    for (final rawAsset in rawAssets) {
      if (rawAsset is! Map) {
        continue;
      }
      final name = rawAsset['name'];
      final downloadUrl = rawAsset['browser_download_url'];
      if (name is! String || downloadUrl is! String) {
        continue;
      }
      final downloadUri = Uri.tryParse(downloadUrl);
      if (downloadUri == null || !downloadUri.hasScheme) {
        continue;
      }
      assets.add(FluxReleaseAsset(name: name, downloadUri: downloadUri));
    }

    final releasePageUri = Uri.tryParse(releasePage);
    if (releasePageUri == null || !releasePageUri.hasScheme) {
      throw const FormatException('GitHub 发布页地址无效');
    }

    return FluxRelease(
      version: FluxSemanticVersion.parse(tag),
      releasePageUri: releasePageUri,
      assets: assets,
    );
  }

  FluxReleaseAsset? assetFor(FluxUpdatePlatform platform) {
    final matchingExtensions = switch (platform) {
      FluxUpdatePlatform.android => ['.apk'],
      FluxUpdatePlatform.macOS => ['.dmg'],
      FluxUpdatePlatform.windows => ['.exe', '.msi', '.zip'],
      FluxUpdatePlatform.linux => ['.appimage', '.deb', '.rpm', '.tar.gz'],
      FluxUpdatePlatform.unsupported => const <String>[],
    };

    for (final asset in assets) {
      final normalizedName = asset.name.toLowerCase();
      if (matchingExtensions.any(normalizedName.endsWith)) {
        return asset;
      }
    }
    return null;
  }
}

class FluxUpdateCheck {
  final FluxSemanticVersion installedVersion;
  final FluxRelease release;
  final FluxUpdatePlatform platform;

  const FluxUpdateCheck({
    required this.installedVersion,
    required this.release,
    required this.platform,
  });

  bool get isUpdateAvailable => release.version.compareTo(installedVersion) > 0;

  FluxReleaseAsset? get installAsset => release.assetFor(platform);
}

FluxUpdatePlatform currentFluxUpdatePlatform() {
  if (Platform.isAndroid) {
    return FluxUpdatePlatform.android;
  }
  if (Platform.isMacOS) {
    return FluxUpdatePlatform.macOS;
  }
  if (Platform.isWindows) {
    return FluxUpdatePlatform.windows;
  }
  if (Platform.isLinux) {
    return FluxUpdatePlatform.linux;
  }
  return FluxUpdatePlatform.unsupported;
}

Future<FluxRelease> fetchLatestFluxRelease({HttpClient Function()? clientFactory}) async {
  final client = (clientFactory ?? HttpClient.new)();
  try {
    final request = await client.getUrl(Uri.parse(fluxLatestReleaseApiUrl)).timeout(const Duration(seconds: 10));
    request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    request.headers.set(HttpHeaders.userAgentHeader, 'Flux update checker');

    final response = await request.close().timeout(const Duration(seconds: 15));
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('GitHub 更新服务返回 HTTP ${response.statusCode}');
    }

    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('GitHub 更新服务返回了无效内容');
    }
    return FluxRelease.fromGitHubJson(json);
  } on TimeoutException {
    throw const HttpException('检查更新超时，请确认网络或稍后重试');
  } finally {
    client.close(force: true);
  }
}

Future<FluxUpdateCheck> checkFluxUpdate() async {
  final packageInfo = await PackageInfo.fromPlatform();
  final installedVersion = FluxSemanticVersion.parse(packageInfo.version);
  final release = await fetchLatestFluxRelease();
  return FluxUpdateCheck(
    installedVersion: installedVersion,
    release: release,
    platform: currentFluxUpdatePlatform(),
  );
}
