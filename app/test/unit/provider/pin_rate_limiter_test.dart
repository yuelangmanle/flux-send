import 'dart:typed_data';

import 'dart:async';

import 'package:localsend_app/provider/network/server/controller/common.dart';
import 'package:localsend_app/util/request_limiter.dart';
import 'package:localsend_app/util/request_limiter.dart';
import 'package:localsend_app/util/security_helper.dart';
import 'package:test/test.dart';

void main() {
  final base = DateTime(2026, 9, 30, 12);

  group('PinRateLimiter', () {
    test('blocks an ip after three failures inside the window', () {
      final limiter = PinRateLimiter();
      limiter.registerFailure('10.0.0.2', base);
      limiter.registerFailure('10.0.0.2', base.add(const Duration(seconds: 10)));
      expect(limiter.isBlocked('10.0.0.2', base.add(const Duration(seconds: 20))), isFalse);
      limiter.registerFailure('10.0.0.2', base.add(const Duration(seconds: 20)));
      expect(limiter.isBlocked('10.0.0.2', base.add(const Duration(seconds: 21))), isTrue);
    });

    test('failures outside the window no longer count', () {
      final limiter = PinRateLimiter(window: const Duration(minutes: 5));
      limiter.registerFailure('10.0.0.3', base);
      limiter.registerFailure('10.0.0.3', base.add(const Duration(minutes: 4)));
      limiter.registerFailure('10.0.0.3', base.add(const Duration(minutes: 6)));
      // 最早的一次失败已滑出窗口，只剩 2 次有效
      expect(limiter.isBlocked('10.0.0.3', base.add(const Duration(minutes: 6, seconds: 1))), isFalse);
    });

    test('a successful attempt clears the failures', () {
      final limiter = PinRateLimiter();
      limiter.registerFailure('10.0.0.4', base);
      limiter.registerFailure('10.0.0.4', base.add(const Duration(seconds: 1)));
      limiter.reset('10.0.0.4');
      expect(limiter.isBlocked('10.0.0.4', base.add(const Duration(seconds: 2))), isFalse);
    });

    test('different ips are tracked independently', () {
      final limiter = PinRateLimiter();
      for (var i = 0; i < 3; i++) {
        limiter.registerFailure('10.0.0.5', base.add(Duration(seconds: i)));
      }
      expect(limiter.isBlocked('10.0.0.5', base.add(const Duration(seconds: 3))), isTrue);
      expect(limiter.isBlocked('10.0.0.6', base.add(const Duration(seconds: 3))), isFalse);
    });
  });

  group('RequestRateLimiter', () {
    test('allows up to the limit then rejects within the window', () {
      final limiter = RequestRateLimiter(maxRequests: 3, window: const Duration(minutes: 1));
      expect(limiter.allow('ip', base), isTrue);
      expect(limiter.allow('ip', base.add(const Duration(seconds: 1))), isTrue);
      expect(limiter.allow('ip', base.add(const Duration(seconds: 2))), isTrue);
      expect(limiter.allow('ip', base.add(const Duration(seconds: 3))), isFalse);
      // 窗口滑过后恢复
      expect(limiter.allow('ip', base.add(const Duration(minutes: 1, seconds: 1))), isTrue);
    });
  });

  group('resolveRequestPin', () {
    test('prefers the header over the query parameter', () {
      expect(resolveRequestPin(headerPin: '1234', queryPin: '0000'), '1234');
    });

    test('falls back to the query parameter when the header is absent', () {
      expect(resolveRequestPin(headerPin: null, queryPin: '5678'), '5678');
    });

    test('treats an empty header as absent', () {
      expect(resolveRequestPin(headerPin: '', queryPin: '5678'), '5678');
    });

    test('returns null when neither is present', () {
      expect(resolveRequestPin(headerPin: null, queryPin: null), isNull);
    });
  });

  group('certificate fingerprint matcher', () {
    test('accepts a certificate whose der hash matches the expected fingerprint', () {
      final securityContext = generateSecurityContext();
      final pemBody = securityContext.certificate
          .replaceAll('\r\n', '\n')
          .split('\n')
          .where((line) => line.isNotEmpty && !line.startsWith('---'))
          .join();
      final der = Uint8List.fromList(Uri.parse('data:application/octet-stream;base64,$pemBody').data!.contentAsBytes());

      expect(
        matchesCertificateBytes(der: der, expectedFingerprint: securityContext.certificateHash),
        isTrue,
      );
      expect(
        matchesCertificateBytes(der: der, expectedFingerprint: securityContext.certificateHash.toUpperCase()),
        isTrue,
      );
      expect(
        matchesCertificateBytes(der: der, expectedFingerprint: '00${securityContext.certificateHash}'),
        isFalse,
      );
    });

    test('accepts anything when no fingerprint is known (manual unregistered peer)', () {
      expect(matchesCertificateBytes(der: Uint8List(0), expectedFingerprint: ''), isTrue);
      expect(matchesCertificateBytes(der: Uint8List(0), expectedFingerprint: '  '), isTrue);
    });
  });

  group('limitBytes stream transformer', () {
    test('passes through data under the limit', () async {
      final controller = StreamController<List<int>>();
      final received = <List<int>>[];
      var done = false;

      controller.stream
          .transform(limitBytes(10))
          .listen(
            received.add,
            onDone: () => done = true,
          );
      controller.add([1, 2, 3]);
      await controller.close();
      await Future<void>.delayed(Duration.zero);

      expect(received, [
        [1, 2, 3],
      ]);
      expect(done, isTrue);
    });

    test('throws BytesLimitExceededException when the cap is exceeded', () async {
      final controller = StreamController<List<int>>();
      Object? caught;

      controller.stream
          .transform(limitBytes(5))
          .listen(
            (_) {},
            onError: (Object e) => caught = e,
          );
      controller.add([1, 2, 3, 4, 5, 6, 7]);
      await controller.close();
      await Future<void>.delayed(Duration.zero);

      expect(caught, isA<BytesLimitExceededException>());
    });
  });
}
