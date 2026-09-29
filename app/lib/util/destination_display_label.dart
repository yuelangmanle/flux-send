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
  final List<String> segments;
  try {
    segments = uri?.pathSegments ?? const <String>[];
  } on ArgumentError {
    return destination;
  } on FormatException {
    return destination;
  }
  final treeIndex = segments.indexOf('tree');
  if (treeIndex == -1 || treeIndex + 1 >= segments.length) {
    return destination;
  }

  final encodedTree = segments[treeIndex + 1];
  final String decodedTree;
  try {
    decodedTree = Uri.decodeComponent(encodedTree);
  } on ArgumentError {
    return destination;
  } on FormatException {
    return destination;
  }
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
