import 'package:localsend_app/provider/update_provider.dart';
import 'package:test/test.dart';

void main() {
  group('FluxRelease', () {
    test('parses a published GitHub release and selects platform assets', () {
      final release = FluxRelease.fromGitHubJson({
        'tag_name': 'v1.2.3',
        'html_url': 'https://github.com/yuelangmanle/flux-send/releases/tag/v1.2.3',
        'prerelease': false,
        'draft': false,
        'assets': [
          {
            'name': 'Flux-v1.2.3-android.apk',
            'browser_download_url': 'https://example.com/Flux-v1.2.3-android.apk',
          },
          {
            'name': 'Flux-v1.2.3-macOS.dmg',
            'browser_download_url': 'https://example.com/Flux-v1.2.3-macOS.dmg',
          },
        ],
      });

      expect(release.version.toString(), '1.2.3');
      expect(release.assetFor(FluxUpdatePlatform.android)?.name, 'Flux-v1.2.3-android.apk');
      expect(release.assetFor(FluxUpdatePlatform.macOS)?.name, 'Flux-v1.2.3-macOS.dmg');
      expect(release.assetFor(FluxUpdatePlatform.windows), isNull);
    });

    test('rejects draft and pre-release payloads', () {
      final release = {
        'tag_name': 'v1.2.3-beta.1',
        'html_url': 'https://example.com/release',
        'prerelease': true,
        'draft': false,
        'assets': <Object?>[],
      };

      expect(() => FluxRelease.fromGitHubJson(release), throwsFormatException);
    });
  });

  group('FluxSemanticVersion', () {
    test('compares semantic versions and ignores build metadata', () {
      expect(FluxSemanticVersion.parse('1.2.3+7').compareTo(FluxSemanticVersion.parse('1.2.3')), 0);
      expect(FluxSemanticVersion.parse('1.2.3').compareTo(FluxSemanticVersion.parse('1.2.4')), lessThan(0));
      expect(FluxSemanticVersion.parse('v2.0.0').compareTo(FluxSemanticVersion.parse('1.9.9')), greaterThan(0));
    });
  });
}
