import 'package:common/model/file_type.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:localsend_app/model/persistence/receive_history_entry.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_app/provider/receive_history_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

void main() {
  late PersistenceService persistenceService;

  setUpAll(() async {
    await initializeDateFormatting();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    persistenceService = PersistenceService.forTesting(await SharedPreferences.getInstance());
  });

  test('Should add an entry', () async {
    final service = ReduxNotifier.test(
      redux: ReceiveHistoryService(persistenceService),
    );

    final entry = _createEntry('1');

    await service.dispatchAsync(_addEntry(entry));

    expect(service.state, [entry]);
    expect(persistenceService.getReceiveHistory(), [entry]);
  });

  test('Should not add an entry if disabled', () async {
    await persistenceService.setSaveToHistory(false);

    final service = ReduxNotifier.test(
      redux: ReceiveHistoryService(persistenceService),
    );

    final entry = _createEntry('1');

    await service.dispatchAsync(_addEntry(entry));

    expect(service.state, []);
    expect(persistenceService.getReceiveHistory(), isEmpty);
  });

  test('Should remove the 30th entry when adding another', () async {
    final service = ReduxNotifier.test(
      redux: ReceiveHistoryService(persistenceService),
      initialState: List.generate(30, (index) => _createEntry(index.toString())),
    );

    expect(service.state.length, 30);
    expect(service.state.first, _createEntry('0'));
    expect(service.state.last, _createEntry('29'));

    final entry = _createEntry('AAA');

    await service.dispatchAsync(_addEntry(entry));

    expect(service.state.length, 30);
    expect(service.state.first, entry);
    expect(service.state.first, _createEntry('AAA'));
    expect(service.state[1], _createEntry('0'));
    expect(service.state.last, _createEntry('28'));
    expect(persistenceService.getReceiveHistory(), service.state);
  });

  test('Should remove an entry', () async {
    final service = ReduxNotifier.test(
      redux: ReceiveHistoryService(persistenceService),
      initialState: [
        _createEntry('1'),
        _createEntry('2'),
        _createEntry('3'),
      ],
    );

    expect(service.state.length, 3);

    await service.dispatchAsync(RemoveHistoryEntryAction('2'));

    expect(service.state.length, 2);
    expect(service.state, [
      _createEntry('1'),
      _createEntry('3'),
    ]);
    expect(persistenceService.getReceiveHistory(), [
      _createEntry('1'),
      _createEntry('3'),
    ]);
  });

  test('Should not remove an entry if not found', () async {
    final service = ReduxNotifier.test(
      redux: ReceiveHistoryService(persistenceService),
      initialState: [
        _createEntry('1'),
        _createEntry('2'),
        _createEntry('3'),
      ],
    );

    expect(service.state.length, 3);

    await service.dispatchAsync(RemoveHistoryEntryAction('4'));

    expect(service.state.length, 3);
    expect(service.state, [
      _createEntry('1'),
      _createEntry('2'),
      _createEntry('3'),
    ]);
    expect(persistenceService.getReceiveHistory(), isEmpty);
  });

  test('Should remove all entries', () async {
    final service = ReduxNotifier.test(
      redux: ReceiveHistoryService(persistenceService),
      initialState: [
        _createEntry('1'),
        _createEntry('2'),
        _createEntry('3'),
      ],
    );

    expect(service.state.length, 3);

    await service.dispatchAsync(RemoveAllHistoryEntriesAction());

    expect(service.state.length, 0);
    expect(persistenceService.getReceiveHistory(), []);
  });

  test('groups receive history by day and by file type for file manager views', () {
    final imageToday = _createEntry('image-today').copyWith(
      fileName: 'today.png',
      fileType: FileType.image,
      timestamp: DateTime.utc(2026, 6, 9, 8),
    );
    final pdfToday = _createEntry('pdf-today').copyWith(
      fileName: 'paper.pdf',
      fileType: FileType.pdf,
      timestamp: DateTime.utc(2026, 6, 9, 9),
    );
    final imageYesterday = _createEntry('image-yesterday').copyWith(
      fileName: 'yesterday.png',
      fileType: FileType.image,
      timestamp: DateTime.utc(2026, 6, 8, 12),
    );

    final byDay = groupReceiveHistoryByDay([imageToday, pdfToday, imageYesterday]);
    final byType = groupReceiveHistoryByType([imageToday, pdfToday, imageYesterday]);

    expect(byDay.map((group) => group.label), ['2026-06-09', '2026-06-08']);
    expect(byDay.first.entries.map((entry) => entry.fileName), ['paper.pdf', 'today.png']);
    expect(byType.map((group) => group.label), containsAll(['图片', 'PDF']));
    expect(byType.firstWhere((group) => group.label == '图片').entries, hasLength(2));
  });
}

AddHistoryEntryAction _addEntry(ReceiveHistoryEntry entry) {
  return AddHistoryEntryAction(
    entryId: entry.id,
    fileName: entry.fileName,
    fileType: entry.fileType,
    path: entry.path,
    savedToGallery: entry.savedToGallery,
    isMessage: entry.isMessage,
    fileSize: entry.fileSize,
    senderAlias: entry.senderAlias,
    timestamp: entry.timestamp,
  );
}

ReceiveHistoryEntry _createEntry(String id) {
  return ReceiveHistoryEntry(
    id: id,
    fileName: 'fileName',
    fileType: FileType.image,
    path: 'path',
    savedToGallery: true,
    isMessage: false,
    fileSize: 123,
    senderAlias: 'senderAlias',
    timestamp: DateTime.utc(2021),
  );
}
