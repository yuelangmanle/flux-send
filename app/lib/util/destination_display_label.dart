String describeDestinationDisplayLabel({
  required String? destination,
  required String defaultDownloadsLabel,
  required bool isAndroid,
}) {
  if (destination == null || destination.isEmpty) {
    return isAndroid ? '未设置保存目录（点此选择 Download/下载目录）' : defaultDownloadsLabel;
  }

  if (!isAndroid || !destination.startsWith('content://')) {
    return destination;
  }

  final uri = Uri.tryParse(destination);
  final segments = uri?.pathSegments ?? const <String>[];
  final treeIndex = segments.indexOf('tree');
  if (treeIndex == -1 || treeIndex + 1 >= segments.length) {
    return destination;
  }

  final decodedTree = Uri.decodeComponent(segments[treeIndex + 1]);
  final colonIndex = decodedTree.indexOf(':');
  if (colonIndex == -1 || colonIndex + 1 >= decodedTree.length) {
    return decodedTree;
  }

  final volume = decodedTree.substring(0, colonIndex);
  final path = decodedTree.substring(colonIndex + 1);
  if (path.isEmpty) {
    return volume == 'primary' ? '内部存储' : volume;
  }

  return path;
}
