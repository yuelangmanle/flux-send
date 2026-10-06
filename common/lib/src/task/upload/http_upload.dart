import 'dart:convert';
import 'package:common/api_route_builder.dart';
import 'package:common/model/device.dart';
import 'package:common/src/isolate/child/http_provider.dart';
import 'package:refena/refena.dart';

final httpUploadProvider = ViewProvider((ref) {
  final client = ref.watch(httpProvider).longLiving;
  return HttpUploadService(client);
});

class HttpUploadService {
  final CustomHttpClient _client;

  HttpUploadService(this._client);

  /// 探询接收端已暂存的字节数（断点续传）。对端不支持时返回 0。
  Future<int> probeResumeOffset({
    required Device target,
    required String? remoteSessionId,
    required String fileId,
    required String token,
  }) async {
    try {
      final body = await _client.postRaw(
        uri: ApiRoute.upload.target(target),
        query: {
          if (remoteSessionId != null) 'sessionId': remoteSessionId,
          'fileId': fileId,
          'token': token,
        },
        headers: {'X-Flux-Resume-Probe': '1'},
      );
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['offset'] is num) {
        final offset = (decoded['offset'] as num).toInt();
        return offset > 0 ? offset : 0;
      }
    } catch (_) {
      // 对端不支持续传协议时按 0 处理。
    }
    return 0;
  }

  Future<void> upload({
    required Stream<List<int>> stream,
    required int contentLength,
    required String contentType,
    required Device target,
    required String? remoteSessionId,
    required String fileId,
    required String token,
    required void Function(double) onSendProgress,
    required CustomCancelToken cancelToken,
    int resumeOffset = 0,
  }) async {
    await _client.postStream(
      uri: ApiRoute.upload.target(target),
      query: {
        if (remoteSessionId != null) 'sessionId': remoteSessionId,
        'fileId': fileId,
        'token': token,
      },
      headers: {
        'Content-Length': contentLength.toString(),
        'Content-Type': contentType,
        if (resumeOffset > 0) 'X-Flux-Resume-Offset': resumeOffset.toString(),
      },
      stream: stream,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
  }
}
