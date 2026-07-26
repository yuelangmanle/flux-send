import 'package:localsend_app/model/persistence/favorite_device.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
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

  test('Should add a favorite device', () async {
    final service = ReduxNotifier.test(
      redux: FavoritesService(persistenceService),
    );

    expect(service.state, []);

    final device = _createDevice('1');

    await service.dispatchAsync(AddFavoriteAction(device));

    expect(service.state, [device]);
    expect(persistenceService.getFavorites(), [device]);
  });

  test('Should update a favorite device', () async {
    final initialDevice = _createDevice('1', alias: 'A');
    final service = ReduxNotifier.test(
      redux: FavoritesService(persistenceService),
      initialState: [initialDevice],
    );

    expect(service.state, [initialDevice]);
    expect(service.state.first.alias, 'A');

    final updatedDevice = _createDevice('1', alias: 'B');
    await service.dispatchAsync(UpdateFavoriteAction(updatedDevice));

    expect(service.state, [updatedDevice]);
    expect(service.state.first.alias, 'B');
    expect(persistenceService.getFavorites(), [updatedDevice]);
  });

  test('Should not update a favorite device if unknown id', () async {
    final initialDevice = _createDevice('1', alias: 'A');
    final service = ReduxNotifier.test(
      redux: FavoritesService(persistenceService),
      initialState: [initialDevice],
    );

    expect(service.state, [initialDevice]);
    expect(service.state.first.alias, 'A');

    final updatedDevice = _createDevice('2', alias: 'B');
    await service.dispatchAsync(UpdateFavoriteAction(updatedDevice));

    expect(service.state, [initialDevice]);
    expect(service.state.first.alias, 'A');
    expect(persistenceService.getFavorites(), isEmpty);
  });

  test('Should delete favorite device', () async {
    final initialDevice = _createDevice('1', fingerprint: '111');
    final service = ReduxNotifier.test(
      redux: FavoritesService(persistenceService),
      initialState: [initialDevice],
    );

    expect(service.state, [initialDevice]);

    await service.dispatchAsync(RemoveFavoriteAction(deviceFingerprint: '111'));

    expect(service.state, []);
    expect(persistenceService.getFavorites(), []);
  });

  test('Should not delete favorite device if unknown fingerprint', () async {
    final initialDevice = _createDevice('1', fingerprint: '111');
    final service = ReduxNotifier.test(
      redux: FavoritesService(persistenceService),
      initialState: [initialDevice],
    );

    expect(service.state, [initialDevice]);

    await service.dispatchAsync(RemoveFavoriteAction(deviceFingerprint: '222'));

    expect(service.state, [initialDevice]);
    expect(persistenceService.getFavorites(), isEmpty);
  });
}

FavoriteDevice _createDevice(
  String id, {
  String fingerprint = '123',
  String alias = 'A',
}) {
  return FavoriteDevice(
    id: id,
    fingerprint: fingerprint,
    ip: '1.2.3.4',
    port: 123,
    alias: alias,
  );
}
