import 'package:flutter_test/flutter_test.dart';
import 'package:tagged_contact/controllers/contact_controller.dart';
import 'package:tagged_contact/models/app_data.dart';
import 'package:tagged_contact/models/contact_models.dart';
import 'package:tagged_contact/utils/phone_utils.dart';

import 'fake_device_service.dart';

void main() {
  late FakeDeviceService device;
  late ContactController controller;

  setUp(() async {
    device = FakeDeviceService();
    controller = ContactController(device);
    await controller.initialize();
  });

  tearDown(() => controller.dispose());

  test('국가 코드와 구분자를 정규화하되 외국 번호를 합치지 않는다', () {
    expect(normalizePhone('+82 10-1234-5678'), '01012345678');
    expect(normalizePhone('0082 (10) 1234.5678'), '01012345678');
    expect(normalizePhone('+1 201-555-0123'), '+12015550123');
    expect(isUsablePhone('-1'), isFalse);
    expect(isUsablePhone('010;1234'), isFalse);
  });

  test('한글 초성과 영문, 숫자를 그룹화한다', () {
    expect(initialGroup('김민서'), 'ㄱ');
    expect(initialGroup('까치'), 'ㄲ');
    expect(initialGroup('홍길동'), 'ㅎ');
    expect(initialGroup('alice'), 'A');
    expect(initialGroup('01012345678'), '#');
  });

  test('태그 길이는 이모지와 조합 문자를 한 글자로 계산한다', () {
    expect(validateTag('가나다라마바사아자차'), isNull);
    expect(validateTag('가나다라마바사아자차카'), isNotNull);
    expect(validateTag('👨‍👩‍👧‍👦' * 10), isNull);
    expect(validateTag('   '), isNotNull);
  });

  test('이름 우선 표시, 태그 우선 표시, 이름·태그·초성 검색', () async {
    await controller.saveTags('01012345678', ['산책친구']);
    await controller.saveTags('+82 10-9999-8888', ['동네꽃집', '예약']);
    expect(controller.titleFor('01012345678'), '김민서');
    expect(controller.titleFor('01099998888'), '동네꽃집');
    expect(controller.visibleContacts('산책').single.name, '김민서');
    expect(controller.visibleContacts('ㄱㅁㅅ').single.name, '김민서');
    expect(controller.visibleContacts('ㄷㄴㄲㅈ').single.key, '01099998888');
    expect(controller.tagsFor('010-9999-8888'), ['동네꽃집', '예약']);
  });

  test('태그 순서와 설정은 앱을 다시 열어도 유지된다', () async {
    await controller.saveTags('01099998888', ['예약', '동네꽃집']);
    await controller.updateSettings(
      (settings) =>
          settings.copyWith(fontScale: 1.2, suggestionsEnabled: false),
    );
    final reopened = ContactController(device);
    await reopened.initialize();
    expect(reopened.tagsFor('01099998888'), ['예약', '동네꽃집']);
    expect(reopened.titleFor('01099998888'), '예약');
    expect(reopened.settings.fontScale, 1.2);
    expect(reopened.settings.suggestionsEnabled, isFalse);
    reopened.dispose();
  });

  test('중복과 긴 태그는 저장하지 않는다', () async {
    expect(
      () => controller.saveTags('01012345678', ['친구', '친구']),
      throwsFormatException,
    );
    expect(
      () => controller.saveTags('01012345678', ['가' * 11]),
      throwsFormatException,
    );
    expect(controller.tagsFor('01012345678'), isEmpty);
  });

  test('저장 실패 시 이전 태그를 유지하며 다음 쓰기는 복구된다', () async {
    await controller.saveTags('01012345678', ['친구']);
    device.failSave = true;
    await expectLater(
      controller.saveTags('01012345678', ['거래처']),
      throwsStateError,
    );
    expect(controller.tagsFor('01012345678'), ['친구']);
    device.failSave = false;
    await controller.saveTags('01012345678', ['산책']);
    expect(controller.tagsFor('01012345678'), ['산책']);
  });

  test('동시에 변경한 설정과 태그를 잃지 않는다', () async {
    await Future.wait([
      controller.saveTags('01012345678', ['친구']),
      controller.saveTags('01099998888', ['꽃집']),
      controller.updateSettings(
        (settings) => settings.copyWith(fontScale: 1.4),
      ),
      controller.updateSettings(
        (settings) => settings.copyWith(suggestionsEnabled: false),
      ),
    ]);
    expect(controller.taggedCount, 2);
    expect(controller.settings.fontScale, 1.4);
    expect(controller.settings.suggestionsEnabled, isFalse);
  });

  test('마지막 태그 삭제 시 미등록 번호를 연락처 목록에서 제거한다', () async {
    await controller.saveTags('01099998888', ['꽃집']);
    await controller.saveTags('01099998888', []);
    expect(controller.visibleContacts('01099998888'), isEmpty);
    expect(controller.visibleContacts('김민서'), hasLength(1));
  });

  test('권한 철회 후 기기 데이터는 제거하고 로컬 태그는 보존한다', () async {
    await controller.saveTags('01012345678', ['친구']);
    device.grants = const DevicePermissions();
    await controller.refresh();
    expect(controller.calls, isEmpty);
    expect(controller.savedContactCount, 0);
    expect(controller.titleFor('01012345678'), '친구');
  });

  test('손상된 로컬 파일은 덮어쓰지 않는다', () async {
    device.failLoad = true;
    final broken = ContactController(device);
    await broken.initialize();
    expect(broken.storageReady, isFalse);
    expect(broken.error, isNotNull);
    await expectLater(broken.saveTags('01012345678', ['친구']), throwsStateError);
    broken.dispose();
  });

  test('통화기록은 페이지 단위로 불러온다', () async {
    device.phoneCalls = List.generate(
      205,
      (index) => PhoneCall(
        id: '$index',
        number: '01012345678',
        date: DateTime(2026, 9, 7).subtract(Duration(minutes: index)),
        kind: CallKind.incoming,
      ),
    );
    await controller.refresh();
    expect(controller.calls, hasLength(100));
    await controller.loadMoreCalls();
    expect(controller.calls, hasLength(200));
    await controller.loadMoreCalls();
    expect(controller.calls, hasLength(205));
    expect(controller.hasMoreCalls, isFalse);
  });

  test('녹음 파일 연결 정보는 저장하고 연결만 해제한다', () async {
    final recording = LinkedRecording(
      uri: 'content://test/audio/1',
      name: '통화.m4a',
      addedAt: DateTime(2026, 9, 7),
    );
    await controller.addRecording('01012345678', recording);
    expect(
      AppData.fromJson(device.stored.toJson())
          .recordings['01012345678']!
          .single
          .name,
      '통화.m4a',
    );
    await controller.removeRecording('01012345678', recording.uri);
    expect(controller.recordingsFor('01012345678'), isEmpty);
  });
}
