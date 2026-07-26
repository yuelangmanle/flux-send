import 'package:common/model/dto/file_dto.dart';
import 'package:common/model/file_type.dart';

bool shouldRequireExplicitReceiveDirectory({
  required bool isAndroid,
  required String? destination,
  required bool saveToGallery,
  required Iterable<FileDto> files,
}) {
  if (!isAndroid || destination != null && destination.isNotEmpty) {
    return false;
  }

  if (!saveToGallery) {
    return true;
  }

  return files.any((file) => file.fileName.contains('/') || !_canSaveToGallery(file.fileType));
}

String describeMissingReceiveDirectoryForAndroid() {
  return '请先在接收端 Flux 的「设置 > 接收 > 保存目录」选择 Download/下载目录；未设置时 Android 可能只能写入应用私有目录，文件会很难找到。';
}

bool _canSaveToGallery(FileType fileType) {
  return fileType == FileType.image || fileType == FileType.video;
}
