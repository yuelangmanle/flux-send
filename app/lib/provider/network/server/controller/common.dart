import 'dart:io';

import 'package:localsend_app/util/simple_server.dart';

/// PIN 错误尝试的时间窗与上限：同一 IP 在窗口内连续失败达到上限即拒绝，
/// 成功后立即清零；窗口外的旧失败自动失效，避免误伤同 NAT 的其他用户。
class PinRateLimiter {
  final Duration window;
  final int maxAttempts;
  final Map<String, List<DateTime>> _failures = {};

  PinRateLimiter({
    this.window = const Duration(minutes: 5),
    this.maxAttempts = 3,
  });

  /// 是否已对该 IP 拒绝服务。
  bool isBlocked(String ip, DateTime now) {
    final attempts = _failures[ip];
    if (attempts == null) {
      return false;
    }
    _failures[ip] = attempts.where((t) => now.difference(t) < window).toList();
    return _failures[ip]!.length >= maxAttempts;
  }

  /// 记录一次失败尝试。
  void registerFailure(String ip, DateTime now) {
    final attempts = (_failures[ip] ?? []).where((t) => now.difference(t) < window).toList();
    attempts.add(now);
    _failures[ip] = attempts;
  }

  /// 成功验证后清空该 IP 的失败记录。
  void reset(String ip) {
    _failures.remove(ip);
  }
}

/// 每个服务进程只有一个 HTTP 服务，限流器随进程存活。
final pinRateLimiter = PinRateLimiter();

/// 从请求中提取 PIN：优先 `X-Pin` 请求头（不进日志与 URL），兼容上游 LocalSend 的 query 参数方式。
String? extractRequestPin(HttpRequest request) {
  return resolveRequestPin(
    headerPin: request.headers.value('X-Pin'),
    queryPin: request.uri.queryParameters['pin'],
  );
}

/// 纯逻辑版本，便于单测。
String? resolveRequestPin({String? headerPin, String? queryPin}) {
  if (headerPin != null && headerPin.isNotEmpty) {
    return headerPin;
  }
  return queryPin;
}

/// Responds with 401 or 429 if the pin is invalid or too many attempts.
/// Returns true if the pin is correct, or if no pin is set.
Future<bool> checkPin({
  required String? pin,
  required HttpRequest request,
  PinRateLimiter? limiter,
  DateTime Function()? clock,
}) async {
  if (pin == null || pin.isEmpty) {
    return true;
  }

  final effectiveLimiter = limiter ?? pinRateLimiter;
  final now = (clock ?? DateTime.now)();
  if (effectiveLimiter.isBlocked(request.ip, now)) {
    await request.respondJson(429, message: 'Too many attempts.');
    return false;
  }

  final requestPin = extractRequestPin(request);
  if (requestPin != pin) {
    if (requestPin?.isNotEmpty ?? false) {
      effectiveLimiter.registerFailure(request.ip, now);
      if (effectiveLimiter.isBlocked(request.ip, now)) {
        await request.respondJson(429, message: 'Too many attempts.');
        return false;
      }
    }
    await request.respondJson(401, message: 'Invalid pin.');
    return false;
  }

  effectiveLimiter.reset(request.ip);
  return true;
}
