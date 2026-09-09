import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagged_contact/services/device_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('tagged_contact/device');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('문자 조회 식별자를 보존하고 원문 열기에 전달한다', () async {
    final opened = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'messages') {
        return [
          {
            'id': '42',
            'threadId': '7',
            'number': '01012345678',
            'body': '원문 확인용 문자',
            'date': DateTime(2026, 9, 9).millisecondsSinceEpoch,
            'type': 1,
          },
        ];
      }
      opened.add(call);
      return null;
    });

    final device = DeviceService();
    final message = (await device.messages('01012345678')).single;
    expect(message.incoming, isTrue);
    await device.openMessage(message);
    expect(opened.single.method, 'openMessage');
    // 메시지 본문을 새 문자 작성 내용으로 넘기지 않는다.
    expect(opened.single.arguments, {
      'id': '42',
      'threadId': '7',
      'number': '01012345678',
    });
  });
}
