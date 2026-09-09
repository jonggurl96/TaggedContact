import 'package:tagged_contact/models/app_data.dart';
import 'package:tagged_contact/models/contact_models.dart';
import 'package:tagged_contact/services/device_service.dart';
import 'package:tagged_contact/utils/phone_utils.dart';

// 테스트 데이터는 실제 기기 저장소와 분리한다.
class FakeDeviceService extends DeviceService {
  AppData stored = const AppData();
  DevicePermissions grants = const DevicePermissions(
    contacts: true,
    calls: true,
    sms: true,
  );
  bool failSave = false;
  bool failLoad = false;
  bool failHistory = false;
  bool failOpenMessage = false;
  final historyOffsets = <int>[];
  final actions = <String>[];
  List<PhoneContact> phoneContacts = const [
    PhoneContact(number: '010-1234-5678', name: '김민서'),
    PhoneContact(number: '010-2222-3333', name: '박지훈'),
  ];
  List<PhoneCall> phoneCalls = [
    PhoneCall(
      id: '1',
      number: '01012345678',
      date: DateTime.now(),
      kind: CallKind.incoming,
      duration: 125,
    ),
    PhoneCall(
      id: '2',
      number: '01099998888',
      date: DateTime.now().subtract(const Duration(hours: 1)),
      kind: CallKind.missed,
    ),
  ];

  @override
  bool get isSupported => true;

  @override
  Future<AppData> load() async {
    if (failLoad) throw const FormatException('손상된 파일');
    return AppData.fromJson(stored.toJson());
  }

  @override
  Future<void> save(AppData data) async {
    if (failSave) throw StateError('저장 공간 부족');
    stored = AppData.fromJson(data.toJson());
  }

  @override
  Future<DevicePermissions> permissions() async => grants;

  @override
  Future<void> requestPermission(String kind) async {
    grants = DevicePermissions(
      contacts: grants.contacts || kind == 'contacts',
      calls: grants.calls || kind == 'calls',
      sms: grants.sms || kind == 'sms',
    );
  }

  @override
  Future<List<PhoneContact>> contacts() async => phoneContacts;

  @override
  Future<List<PhoneCall>> calls({int offset = 0}) async =>
      phoneCalls.skip(offset).take(100).toList();

  @override
  Future<List<PhoneCall>> history(String number, {int offset = 0}) async {
    historyOffsets.add(offset);
    if (failHistory) throw StateError('통화기록 조회 실패');
    return phoneCalls
        .where((call) => call.key == normalizePhone(number))
        .skip(offset)
        .take(100)
        .toList();
  }

  @override
  Future<List<PhoneMessage>> messages(String number) async => [
    PhoneMessage(
      id: '42',
      threadId: '7',
      number: number,
      body: '내일 산책 모임에서 만나요!',
      date: DateTime.now(),
      incoming: true,
    ),
  ];

  @override
  Future<void> dial(String number) async => actions.add('dial:$number');

  @override
  Future<void> composeMessage(String number) async =>
      actions.add('sms:$number');

  @override
  Future<void> openMessage(PhoneMessage message) async {
    if (failOpenMessage) throw StateError('메시지 앱 실행 실패');
    actions.add('message:${message.id}:${message.threadId}:${message.number}');
  }

  @override
  Future<void> insertContact(String number) async =>
      actions.add('save:$number');

  @override
  Future<void> openSettings() async => actions.add('settings');
}
