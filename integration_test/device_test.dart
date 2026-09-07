import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tagged_contact/app.dart';
import 'package:tagged_contact/controllers/contact_controller.dart';
import 'package:tagged_contact/models/app_data.dart';
import 'package:tagged_contact/services/device_service.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android 로컬 저장·연락처·통화·문자 및 화면을 검증한다', (tester) async {
    final device = DeviceService();
    final original = await device.load();
    final controller = ContactController(device);
    try {
      await device.save(const AppData());
      await controller.initialize();
      expect(controller.storageReady, isTrue);
      expect(controller.error, isNull);
      final grants = await device.permissions();
      expect(
        grants.contacts && grants.calls && grants.sms,
        isTrue,
        reason: '테스트 전용 에뮬레이터에 README의 권한 및 샘플 데이터를 준비해 주세요.',
      );

      // 실제 ContentProvider에 국가 코드 표기를 섞어 저장한 테스트 번호다.
      final contacts = await device.contacts();
      expect(contacts.any((contact) => contact.key == '01090000001'), isTrue);
      final history = await device.history('01090000001');
      expect(history, hasLength(100));
      final older = await device.history('01090000001', offset: 100);
      expect(older, hasLength(5));
      expect(history.every((call) => call.key == '01090000001'), isTrue);
      expect(
        history
            .map((call) => call.id)
            .toSet()
            .intersection(older.map((call) => call.id).toSet()),
        isEmpty,
      );
      final messages = await device.messages('01090000001');
      // Android 37은 외부에서 넣은 합성 문자를 보호 대상으로 분류할 수 있다.
      if (const bool.fromEnvironment('SMS_FIXTURE_RESTRICTED')) {
        expect(messages, isEmpty, reason: '시스템에서 보호하는 문자를 표시하지 않아야 합니다.');
      } else {
        expect(messages, isNotEmpty);
        expect(messages.first.body, contains('검증 문자'));
      }
      await expectLater(
        device.dial('010;1234'),
        throwsA(isA<PlatformException>()),
      );

      await controller.saveTags('+82 10-9000-0001', ['산책친구', '독서모임']);
      await controller.saveTags('01090000002', ['동네꽃집']);
      final restored = await device.load();
      expect(restored.tags['01090000001'], ['산책친구', '독서모임']);
      await controller.updateSettings(
        (settings) => settings.copyWith(fontScale: 1.1),
      );
      expect((await device.load()).settings.fontScale, 1.1);

      await tester.pumpWidget(TaggedContactApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('번호 너머,\n기억하고 싶은 관계.'), findsOneWidget);
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      final home = await binding.takeScreenshot('통화기록');
      await File('${Directory.systemTemp.path}/tagged_home.png')
          .writeAsBytes(home);
      await tester.tap(find.text('연락처').last);
      await tester.pumpAndSettle();
      final contactsImage = await binding.takeScreenshot('연락처');
      await File('${Directory.systemTemp.path}/tagged_contacts.png')
          .writeAsBytes(contactsImage);
      await tester.tap(find.text('환경설정').last);
      await tester.pumpAndSettle();
      final settingsImage = await binding.takeScreenshot('환경설정');
      await File('${Directory.systemTemp.path}/tagged_settings.png')
          .writeAsBytes(settingsImage);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      // 테스트가 실패해도 실행 전 로컬 상태를 복구한다.
      await device.save(original);
      controller.dispose();
    }
  });
}
