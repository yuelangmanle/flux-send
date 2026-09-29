import 'package:localsend_app/util/destination_display_label.dart';
import 'package:test/test.dart';

void main() {
  test('describes Android default receive destination as requiring explicit folder choice', () {
    expect(
      describeDestinationDisplayLabel(
        destination: null,
        defaultDownloadsLabel: '(下载)',
        isAndroid: true,
      ),
      '未设置保存目录（点此选择 Download/下载目录）',
    );
  });

  test('shows readable Android SAF destination names instead of raw content uri', () {
    expect(
      describeDestinationDisplayLabel(
        destination: 'content://com.android.externalstorage.documents/tree/primary%3ADownload',
        defaultDownloadsLabel: '(下载)',
        isAndroid: true,
      ),
      'Download',
    );

    expect(
      describeDestinationDisplayLabel(
        destination: 'content://com.android.externalstorage.documents/tree/primary%3ADownload%2FFlux',
        defaultDownloadsLabel: '(下载)',
        isAndroid: true,
      ),
      'Download/Flux',
    );
  });

  test('keeps malformed Android SAF URI readable instead of throwing in settings', () {
    const malformedUri = 'content://com.android.externalstorage.documents/tree/primary%broken';

    expect(
      () => describeDestinationDisplayLabel(
        destination: malformedUri,
        defaultDownloadsLabel: '(下载)',
        isAndroid: true,
      ),
      returnsNormally,
    );
    expect(
      describeDestinationDisplayLabel(
        destination: malformedUri,
        defaultDownloadsLabel: '(下载)',
        isAndroid: true,
      ),
      malformedUri,
    );
  });

  test('keeps truncated percent-encoded UTF-8 SAF URI readable instead of throwing', () {
    const truncatedUri = 'content://com.android.externalstorage.documents/tree/primary%3ADownload%2F%E4%B8';

    expect(
      () => describeDestinationDisplayLabel(
        destination: truncatedUri,
        defaultDownloadsLabel: '(下载)',
        isAndroid: true,
      ),
      returnsNormally,
    );
    expect(
      describeDestinationDisplayLabel(
        destination: truncatedUri,
        defaultDownloadsLabel: '(下载)',
        isAndroid: true,
      ),
      truncatedUri,
    );
  });

  test('keeps desktop defaults and paths unchanged', () {
    expect(
      describeDestinationDisplayLabel(
        destination: null,
        defaultDownloadsLabel: '(Downloads)',
        isAndroid: false,
      ),
      '(Downloads)',
    );
    expect(
      describeDestinationDisplayLabel(
        destination: '/Users/me/Downloads',
        defaultDownloadsLabel: '(Downloads)',
        isAndroid: false,
      ),
      '/Users/me/Downloads',
    );
  });
}
