import 'dart:io';

import 'package:common/model/dto/file_dto.dart';
import 'package:common/model/file_type.dart';
import 'package:localsend_app/util/receive_destination_policy.dart';
import 'package:test/test.dart';

void main() {
  test('Android requires an explicit receive folder for non-gallery transfers', () {
    expect(
      shouldRequireExplicitReceiveDirectory(
        isAndroid: true,
        destination: null,
        saveToGallery: false,
        files: [_file('document.pdf', FileType.pdf)],
      ),
      isTrue,
    );
    expect(
      shouldRequireExplicitReceiveDirectory(
        isAndroid: true,
        destination: '',
        saveToGallery: false,
        files: [_file('folder/document.pdf', FileType.pdf)],
      ),
      isTrue,
    );
  });

  test('Android may receive gallery-only media without an explicit receive folder', () {
    expect(
      shouldRequireExplicitReceiveDirectory(
        isAndroid: true,
        destination: null,
        saveToGallery: true,
        files: [_file('photo.jpg', FileType.image), _file('clip.mp4', FileType.video)],
      ),
      isFalse,
    );
  });

  test('explicit Android SAF destination and desktop defaults are allowed', () {
    expect(
      shouldRequireExplicitReceiveDirectory(
        isAndroid: true,
        destination: 'content://com.android.externalstorage.documents/tree/primary%3ADownload',
        saveToGallery: false,
        files: [_file('document.pdf', FileType.pdf)],
      ),
      isFalse,
    );
    expect(
      shouldRequireExplicitReceiveDirectory(
        isAndroid: false,
        destination: null,
        saveToGallery: false,
        files: [_file('document.pdf', FileType.pdf)],
      ),
      isFalse,
    );
  });

  test('describes missing Android receive folder with actionable text', () {
    expect(
      describeMissingReceiveDirectoryForAndroid(),
      '请先在接收端 Flux 的「设置 > 接收 > 保存目录」选择 Download/下载目录；未设置时 Android 可能只能写入应用私有目录，文件会很难找到。',
    );
  });

  test('receive controller rejects Android file requests before using a private default directory', () {
    final source = File('lib/provider/network/server/controller/receive_controller.dart').readAsStringSync();

    expect(source, contains('shouldRequireExplicitReceiveDirectory'));
    expect(source, contains('describeMissingReceiveDirectoryForAndroid()'));
    expect(source, contains('request.respondJson(409'));

    final policyIndex = source.indexOf('shouldRequireExplicitReceiveDirectory');
    final defaultDirectoryIndex = source.indexOf('getDefaultDestinationDirectory()');
    expect(policyIndex, greaterThanOrEqualTo(0));
    expect(defaultDirectoryIndex, greaterThanOrEqualTo(0));
    expect(policyIndex, lessThan(defaultDirectoryIndex));
  });
}

FileDto _file(String fileName, FileType fileType) {
  return FileDto(
    id: fileName,
    fileName: fileName,
    size: 1,
    fileType: fileType,
    hash: null,
    preview: null,
    metadata: null,
  );
}
