import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagged_contact/app.dart';
import 'package:tagged_contact/controllers/contact_controller.dart';
import 'package:tagged_contact/models/contact_models.dart';
import 'package:tagged_contact/widgets/tag_editor.dart';

import 'fake_device_service.dart';

void main() {
  late FakeDeviceService device;
  late ContactController controller;

  Future<void> prepare() async {
    device = FakeDeviceService();
    controller = ContactController(device);
    await controller.initialize();
  }

  tearDown(() => controller.dispose());

  Future<void> openApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(TaggedContactApp(controller: controller));
    await tester.pumpAndSettle();
  }

  testWidgets('통화기록이 메인이며 세 화면을 이동한다', (tester) async {
    await prepare();
    await openApp(tester);
    expect(find.text('번호 너머,\n기억하고 싶은 관계.'), findsOneWidget);
    await tester.tap(find.text('연락처').last);
    await tester.pumpAndSettle();
    expect(find.text('이름에 기억을 더해요.'), findsOneWidget);
    expect(find.text('김민서'), findsOneWidget);
    await tester.tap(find.text('환경설정').last);
    await tester.pumpAndSettle();
    expect(find.text('나에게 편안한 화면.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('번호를 직접 입력하고 마지막 빈칸의 태그까지 저장한다', (tester) async {
    await prepare();
    await openApp(tester);
    await tester.tap(find.text('번호에 태그'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '010-5555-6666');
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '새 태그'), '새로운인연');
    await tester.tap(find.text('태그 저장'));
    await tester.pumpAndSettle();
    expect(controller.tagsFor('01055556666'), ['새로운인연']);
    expect(find.byType(TagEditor), findsNothing);
  });

  testWidgets('직접 편집, 순서 변경, 추천과 추천 끄기를 적용한다', (tester) async {
    await prepare();
    await controller.saveTags('01012345678', ['산책친구', '모임']);
    await controller.saveTags('01022223333', ['산책모임']);
    await openApp(tester);
    await tester.tap(find.text('연락처').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('김민서'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '새 태그'), '산책');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, '# 산책모임'), findsOneWidget);
    await controller.updateSettings(
      (settings) => settings.copyWith(suggestionsEnabled: false),
    );
    await tester.pumpAndSettle();
    // 입력 변경으로 추천 설정을 즉시 반영한다.
    await tester.enterText(find.widgetWithText(TextField, '새 태그'), '산책모');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, '# 산책모임'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, '새 태그'), '');
    await tester.enterText(find.widgetWithText(TextField, '1번째 태그'), '오랜친구');
    await tester.pumpAndSettle();
    final handles = find.byType(ReorderableDragStartListener);
    final destination = tester.getCenter(handles.last) + const Offset(0, 32);
    final gesture = await tester.startGesture(tester.getCenter(handles.first));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveTo(destination);
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('태그 저장'));
    await tester.pumpAndSettle();
    expect(controller.tagsFor('01012345678'), ['모임', '오랜친구']);
  });

  testWidgets('권한 없이도 빈 화면과 직접 태그 입력을 제공한다', (tester) async {
    await prepare();
    device.grants = const DevicePermissions();
    await controller.refresh();
    await openApp(tester);
    expect(find.text('통화기록을 연결해 주세요'), findsOneWidget);
    expect(find.text('번호에 태그'), findsOneWidget);
    expect(find.text('김민서'), findsNothing);
  });

  testWidgets('저장된 연락처에서는 연락처 저장 버튼을 숨긴다', (tester) async {
    await prepare();
    await openApp(tester);
    expect(find.byTooltip('연락처 저장'), findsOneWidget);
    await tester.tap(find.byTooltip('전화하기').first);
    await tester.pumpAndSettle();
    expect(device.actions, contains('dial:01012345678'));
    await tester.tap(find.byTooltip('문자보내기').first);
    await tester.pumpAndSettle();
    expect(device.actions, contains('sms:01012345678'));
  });

  testWidgets('작은 화면과 큰 글자에서 화면과 입력창이 넘치지 않는다', (tester) async {
    await prepare();
    await controller.updateSettings(
      (settings) => settings.copyWith(fontScale: 1.4),
    );
    await openApp(tester);
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('연락처').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byKey(const PageStorageKey('contacts')),
      const Offset(0, -230),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('김민서'));
    await tester.pumpAndSettle();
    expect(find.byType(TagEditor), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
