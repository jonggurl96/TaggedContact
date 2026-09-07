import 'package:flutter/foundation.dart';

import '../models/app_data.dart';
import '../models/contact_models.dart';
import '../services/device_service.dart';
import '../utils/phone_utils.dart';

class ContactController extends ChangeNotifier {
  ContactController(this.device);

  final DeviceService device;
  AppData _data = const AppData();
  final Map<String, PhoneContact> _contacts = {};
  List<PhoneCall> calls = [];
  DevicePermissions permissions = const DevicePermissions();
  bool loading = true;
  bool refreshing = false;
  bool loadingMore = false;
  bool hasMoreCalls = false;
  bool storageReady = false;
  String? error;
  Future<void> _writeQueue = Future.value();

  AppSettings get settings => _data.settings;
  int get savedContactCount => _contacts.length;
  int get taggedCount => _data.tags.length;
  List<String> get allTags =>
      _data.tags.values.expand((tags) => tags).toSet().toList()..sort();

  Future<void> initialize() async {
    loading = true;
    error = null;
    notifyListeners();
    if (!device.isSupported) {
      error = '기기 연락처와 통화기록은 Android에서 사용할 수 있어요.';
    } else {
      try {
        _data = await device.load();
        storageReady = true;
        await refresh();
      } catch (_) {
        storageReady = false;
        error = '저장된 데이터를 읽지 못했어요. 기존 데이터를 보호하기 위해 저장을 중단했어요. 다시 시도해 주세요.';
      }
    }
    loading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!device.isSupported || refreshing || loadingMore) return;
    refreshing = true;
    error = null;
    notifyListeners();
    try {
      permissions = await device.permissions();
      // 철회된 권한에 해당하는 개인정보는 화면에서도 즉시 제거한다.
      if (!permissions.contacts) _contacts.clear();
      if (!permissions.calls) {
        calls = [];
        hasMoreCalls = false;
      }
      final result = await Future.wait<Object>([
        permissions.contacts
            ? device.contacts()
            : Future.value(<PhoneContact>[]),
        permissions.calls ? device.calls() : Future.value(<PhoneCall>[]),
      ]);
      _contacts.clear();
      for (final contact in result[0] as List<PhoneContact>) {
        if (isUsablePhone(contact.number)) {
          _contacts.putIfAbsent(contact.key, () => contact);
        }
      }
      calls = result[1] as List<PhoneCall>;
      hasMoreCalls = calls.length == 100;
    } catch (_) {
      error = '기기 정보를 불러오지 못했어요. 권한을 확인하고 다시 시도해 주세요.';
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreCalls() async {
    if (loadingMore || refreshing || !hasMoreCalls) return;
    loadingMore = true;
    notifyListeners();
    try {
      final next = await device.calls(offset: calls.length);
      final ids = calls.map((call) => call.id).toSet();
      calls = [...calls, ...next.where((call) => ids.add(call.id))];
      hasMoreCalls = next.length == 100;
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> requestPermission(String kind) async {
    await device.requestPermission(kind);
    await refresh();
  }

  PhoneContact contactFor(String number) =>
      _contacts[normalizePhone(number)] ?? PhoneContact(number: number);

  List<String> tagsFor(String number) =>
      List.unmodifiable(_data.tags[normalizePhone(number)] ?? []);

  List<LinkedRecording> recordingsFor(String number) =>
      List.unmodifiable(_data.recordings[normalizePhone(number)] ?? []);

  String titleFor(String number) {
    final contact = contactFor(number);
    if (contact.name.trim().isNotEmpty) return contact.name;
    final tags = tagsFor(number);
    return tags.isEmpty ? displayPhone(number) : tags.first;
  }

  bool matches(String number, String query) {
    final search = query.trim().toLowerCase();
    if (search.isEmpty) return true;
    final name = contactFor(number).name;
    return name.toLowerCase().contains(search) ||
        normalizePhone(number).contains(normalizePhone(search)) ||
        initialsOf(name).contains(search) ||
        tagsFor(number).any(
          (tag) =>
              tag.toLowerCase().contains(search) ||
              initialsOf(tag).contains(search),
        );
  }

  List<PhoneContact> visibleContacts(String query, {bool taggedOnly = false}) {
    final merged = {..._contacts};
    for (final number in _data.tags.keys) {
      merged.putIfAbsent(number, () => PhoneContact(number: number));
    }
    final result = merged.values
        .where(
          (contact) =>
              matches(contact.number, query) &&
              (!taggedOnly || tagsFor(contact.number).isNotEmpty),
        )
        .toList();
    result.sort((a, b) {
      final aTitle = titleFor(a.number);
      final bTitle = titleFor(b.number);
      final aGroup = initialGroup(aTitle);
      final bGroup = initialGroup(bTitle);
      if (aGroup != bGroup) {
        if (aGroup == '#') return 1;
        if (bGroup == '#') return -1;
        return aGroup.compareTo(bGroup);
      }
      return aTitle.toLowerCase().compareTo(bTitle.toLowerCase());
    });
    return result;
  }

  Future<void> saveTags(String number, List<String> tags) {
    final key = normalizePhone(number);
    if (!isUsablePhone(key)) throw const FormatException('올바른 전화번호를 입력해 주세요.');
    final values = tags.map((tag) => tag.trim()).toList();
    for (final tag in values) {
      final message = validateTag(tag);
      if (message != null) throw FormatException(message);
    }
    if (values.toSet().length != values.length) {
      throw const FormatException('같은 태그는 한 번만 추가할 수 있어요.');
    }
    return _update((data) {
      final next = {...data.tags};
      if (values.isEmpty) {
        next.remove(key);
      } else {
        next[key] = values;
      }
      return data.copyWith(tags: next);
    });
  }

  Future<void> updateSettings(AppSettings Function(AppSettings) update) =>
      _update((data) => data.copyWith(settings: update(data.settings)));

  Future<void> addRecording(String number, LinkedRecording recording) =>
      _update((data) {
        final key = normalizePhone(number);
        final list = data.recordings[key] ?? [];
        return data.copyWith(
          recordings: {
            ...data.recordings,
            key: [
              recording,
              ...list.where((item) => item.uri != recording.uri),
            ],
          },
        );
      });

  Future<void> removeRecording(String number, String uri) => _update((data) {
    final key = normalizePhone(number);
    final next = {...data.recordings};
    final remaining = (next[key] ?? [])
        .where((item) => item.uri != uri)
        .toList();
    if (remaining.isEmpty) {
      next.remove(key);
    } else {
      next[key] = remaining;
    }
    return data.copyWith(recordings: next);
  });

  // 쓰기를 직렬화하고 디스크 저장이 성공한 경우에만 화면 상태를 변경한다.
  Future<void> _update(AppData Function(AppData) change) {
    final operation = _writeQueue.then((_) async {
      if (!storageReady) throw StateError('로컬 저장소를 사용할 수 없어요.');
      final next = change(_data);
      await device.save(next);
      _data = next;
      notifyListeners();
    });
    _writeQueue = operation.catchError((Object _) {});
    return operation;
  }
}
