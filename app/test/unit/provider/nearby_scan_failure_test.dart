import 'package:common/isolate.dart';
import 'package:common/model/device.dart';
import 'package:common/model/device_info_result.dart';
import 'package:common/model/dto/multicast_dto.dart';
import 'package:common/model/stored_security_context.dart';
import 'package:localsend_app/model/persistence/favorite_device.dart';
import 'package:localsend_app/model/state/nearby_devices_state.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/logging/discovery_logs_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

void main() {
  late PersistenceService persistenceService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    persistenceService = PersistenceService.forTesting(await SharedPreferences.getInstance());
  });

  test('legacy scan clears running subnet when isolate discovery fails', () async {
    final service = _nearbyService(persistenceService);

    await expectLater(
      service.dispatchAsync(StartLegacyScan(port: 53317, localIp: '10.0.0.2', https: false)),
      throwsStateError,
    );

    expect(service.state.runningIps, isEmpty);
  });

  test('scan attempts are logged before isolate discovery yields devices', () {
    expect(
      describeLegacyScanStart(localIp: '10.0.0.2', port: 53317),
      '[发现/TCP] 正在扫描 10.0.0.2:53317',
    );
    expect(
      describeFavoriteScanStart(favoriteCount: 2),
      '[发现/TCP] 正在扫描 2 台收藏设备',
    );
  });

  test('UDP discovery and incoming register logs are Chinese', () {
    final device = _device(ip: '10.0.0.3', fingerprint: 'phone');

    expect(
      describeMulticastDeviceDiscovered(device),
      '[发现/UDP] 找到 phone（10.0.0.3，型号：test）',
    );
    expect(
      describeRegisterRequestReceived(alias: 'Flux Phone', ip: '10.0.0.3'),
      '[发现/TCP] 收到 Flux Phone 的注册请求（10.0.0.3）',
    );
  });

  test('scan completion and failure are logged in Chinese so the status card never looks stuck', () {
    expect(
      describeLegacyScanFinished(localIp: '10.0.0.2', port: 53317, foundCount: 0),
      '[发现/TCP] 10.0.0.2:53317 扫描完成，未发现设备',
    );
    expect(
      describeLegacyScanFinished(localIp: '10.0.0.2', port: 53317, foundCount: 2),
      '[发现/TCP] 10.0.0.2:53317 扫描完成，发现 2 台设备',
    );
    expect(
      describeLegacyScanFailed(localIp: '10.0.0.2', port: 53317, error: StateError('boom')),
      '[发现/TCP] 10.0.0.2:53317 扫描失败：Bad state: boom',
    );
  });

  test('favorite scan clears running flag when isolate discovery fails', () async {
    final service = _nearbyService(persistenceService);

    await expectLater(
      service.dispatchAsync(StartFavoriteScan(devices: [_favorite()], https: false)),
      throwsStateError,
    );

    expect(service.state.runningFavoriteScan, isFalse);
  });
}

ReduxNotifierTester<NearbyDevicesState> _nearbyService(PersistenceService persistenceService) {
  final isolateController = _uninitializedIsolateController();
  final discoveryLogger = Notifier.test(notifier: DiscoveryLogger());
  ReduxNotifier.test(redux: isolateController);

  return ReduxNotifier.test(
    redux: NearbyDevicesService(
      isolateController: isolateController,
      favoriteService: FavoritesService(persistenceService),
      discoveryLogs: discoveryLogger.notifier,
      ownFingerprint: () => 'self',
      localIps: () => const ['10.0.0.2'],
    ),
  );
}

IsolateController _uninitializedIsolateController() {
  return IsolateController(
    initialState: ParentIsolateState.initial(
      SyncState(
        init: () async {},
        rootIsolateToken: Object(),
        httpClientFactory: (_, __) => _NoopHttpClient(),
        securityContext: const StoredSecurityContext(
          privateKey: 'private',
          publicKey: 'public',
          certificate: 'certificate',
          certificateHash: 'self',
        ),
        deviceInfo: DeviceInfoResult(
          deviceType: DeviceType.desktop,
          deviceModel: 'test',
          androidSdkInt: null,
        ),
        alias: 'Flux Test',
        port: 53317,
        networkWhitelist: null,
        networkBlacklist: null,
        protocol: ProtocolType.http,
        multicastGroup: '224.0.0.167',
        discoveryTimeout: 500,
        serverRunning: true,
        download: false,
      ),
    ),
  );
}

FavoriteDevice _favorite() {
  return FavoriteDevice(
    id: 'favorite',
    fingerprint: 'phone',
    ip: '10.0.0.3',
    port: 53317,
    alias: 'Phone',
  );
}

Device _device({
  required String ip,
  required String fingerprint,
}) {
  return Device(
    signalingId: null,
    ip: ip,
    version: '2.0',
    port: 53317,
    https: false,
    fingerprint: fingerprint,
    alias: fingerprint,
    deviceModel: 'test',
    deviceType: DeviceType.mobile,
    download: false,
    discoveryMethods: const {},
  );
}

class _NoopHttpClient implements CustomHttpClient {
  @override
  Future<String> get({required String uri, required Map<String, String> query}) async => '{}';

  @override
  Future<String> post({required String uri, Map<String, String> query = const {}, required Map<String, dynamic> json}) async => '{}';

  @override
  Future<void> postStream({
    required String uri,
    required Map<String, String> query,
    required Map<String, String> headers,
    required Stream<List<int>> stream,
    required void Function(double p1) onSendProgress,
    required CustomCancelToken cancelToken,
  }) async {}
}
