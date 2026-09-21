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

  Finder historyList() => find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byType(ListView),
  );

  // 화면 밖의 항목까지 포함해 상세 목록에 제공된 통화 수를 확인한다.
  List<ListTile> historyRows(WidgetTester tester) {
    final list = tester.widget<ListView>(historyList());
    return (list.childrenDelegate as SliverChildListDelegate).children
        .whereType<ListTile>()
        .toList();
  }

  Future<void> tapInHistory(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.descendant(
        of: historyList(),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  void setHistory(int count) {
    device.phoneCalls = List.generate(
      count,
      (index) => PhoneCall(
        id: '$index',
        number: '01012345678',
        date: DateTime(2026, 9, 9).subtract(Duration(minutes: index)),
        kind: CallKind.incoming,
        duration: index + 1,
      ),
    );
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

  testWidgets('연속된 번호는 횟수와 최신 통화만 표시하고 상세에서는 개별 기록을 보여준다', (tester) async {
    await prepare();
    device.phoneCalls = [
      PhoneCall(
        id: '1',
        number: '01012345678',
        date: DateTime(2026, 9, 21, 0, 1),
        kind: CallKind.outgoing,
        duration: 60,
      ),
      PhoneCall(
        id: '2',
        number: '+82 10-1234-5678',
        date: DateTime(2026, 9, 20, 23, 59),
        kind: CallKind.incoming,
        duration: 120,
      ),
      PhoneCall(
        id: '3',
        number: '010-1234-5678',
        date: DateTime(2026, 9, 20, 23, 58),
        kind: CallKind.missed,
      ),
      PhoneCall(
        id: '4',
        number: '01022223333',
        date: DateTime(2026, 9, 20, 23, 57),
        kind: CallKind.outgoing,
      ),
      PhoneCall(
        id: '5',
        number: '01012345678',
        date: DateTime(2026, 9, 20, 23, 56),
        kind: CallKind.missed,
      ),
    ];
    await controller.refresh();
    await openApp(tester);
    tester.view.physicalSize = const Size(430, 1400);
    await tester.pumpAndSettle();
    expect(find.text('김민서 (3)'), findsOneWidget);
    expect(find.text('박지훈'), findsOneWidget);
    expect(find.text('김민서'), findsOneWidget);
    expect(find.text('발신 · 00:01'), findsOneWidget);
    expect(find.text('· 1분 0초'), findsOneWidget);
    expect(find.text('수신 · 23:59'), findsNothing);
    expect(find.text('· 2분 0초'), findsNothing);

    await tester.tap(find.text('김민서 (3)'));
    await tester.pumpAndSettle();
    expect(historyRows(tester), hasLength(4));
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();

    // 부재중 필터에서는 표시 대상인 부재중 통화만 집계한다.
    await tester.tap(find.widgetWithText(ChoiceChip, '부재중'));
    await tester.pumpAndSettle();
    expect(find.text('김민서 (2)'), findsOneWidget);
    expect(find.text('부재중 · 23:58'), findsOneWidget);
    expect(find.text('발신 · 00:01'), findsNothing);
    expect(find.text('박지훈'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, '전체'));
    await tester.enterText(find.byType(TextField), '김민서');
    await tester.pumpAndSettle();
    expect(find.text('김민서 (4)'), findsOneWidget);
    expect(find.text('발신 · 00:01'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('다음 페이지의 연속된 통화는 기존 항목의 횟수에 더한다', (tester) async {
    await prepare();
    setHistory(103);
    await controller.refresh();
    await openApp(tester);
    expect(find.text('김민서 (100)'), findsOneWidget);
    final more = find.text('이전 통화 100건 더 보기');
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('김민서 (103)'), findsOneWidget);
    expect(find.text('김민서 (100)'), findsNothing);
    expect(find.text('수신 · 00:00'), findsOneWidget);
    expect(more, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('이름이 같아도 번호가 다르거나 표시제한이면 각각 표시한다', (tester) async {
    await prepare();
    device.phoneContacts = const [
      PhoneContact(number: '01012345678', name: '동명이인'),
      PhoneContact(number: '01022223333', name: '동명이인'),
    ];
    device.phoneCalls = [
      for (final (index, number) in [
        '01012345678',
        '01022223333',
        '',
        '',
      ].indexed)
        PhoneCall(
          id: '$index',
          number: number,
          date: DateTime(2026, 9, 21, 12).subtract(Duration(minutes: index)),
          kind: CallKind.incoming,
        ),
    ];
    await controller.refresh();
    await openApp(tester);
    tester.view.physicalSize = const Size(430, 1600);
    await tester.pumpAndSettle();
    expect(find.text('동명이인'), findsNWidgets(2));
    expect(find.text('발신번호 표시제한'), findsNWidgets(2));
    expect(find.text('동명이인 (2)'), findsNothing);
    expect(find.text('발신번호 표시제한 (2)'), findsNothing);
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

  testWidgets('통화 상세는 5건으로 시작하고 10건씩 늘며 마지막에는 더보기를 숨긴다', (tester) async {
    await prepare();
    setHistory(16);
    await openApp(tester);
    await tester.tap(find.text('김민서').first);
    await tester.pumpAndSettle();
    expect(historyRows(tester), hasLength(5));

    final more = find.text('이전 통화 10건 더 보기');
    await tapInHistory(tester, more);
    expect(historyRows(tester), hasLength(15));
    await tapInHistory(tester, more);
    expect(historyRows(tester), hasLength(16));
    expect(more, findsNothing);
    expect(device.historyOffsets, [0]);

    await tester.tap(find.byTooltip('기록 새로고침'));
    await tester.pumpAndSettle();
    expect(historyRows(tester), hasLength(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('조회한 100건을 넘길 때만 추가 조회하고 실패 후 재시도할 수 있다', (tester) async {
    await prepare();
    setHistory(103);
    await openApp(tester);
    await tester.tap(find.text('김민서').first);
    await tester.pumpAndSettle();
    final more = find.text('이전 통화 10건 더 보기');
    for (var count = 15; count <= 95; count += 10) {
      await tapInHistory(tester, more);
      expect(historyRows(tester), hasLength(count));
    }
    expect(device.historyOffsets, [0]);

    device.failHistory = true;
    await tapInHistory(tester, more);
    expect(historyRows(tester), hasLength(95));
    expect(find.byType(SnackBar), findsOneWidget);
    device.failHistory = false;
    await tapInHistory(tester, more);
    expect(historyRows(tester), hasLength(103));
    final subtitles = historyRows(tester)
        .map((row) => (row.subtitle! as Text).data);
    expect(subtitles.toSet(), hasLength(103));
    expect(device.historyOffsets, [0, 100, 100]);
    expect(more, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final count in [0, 3, 5]) {
    testWidgets('통화 상세가 $count건이면 더보기를 표시하지 않는다', (tester) async {
      await prepare();
      setHistory(count);
      await openApp(tester);
      await tester.tap(find.text('김민서').first);
      await tester.pumpAndSettle();
      expect(historyRows(tester), hasLength(count));
      expect(find.text('이전 통화 10건 더 보기'), findsNothing);
      if (count == 0) {
        expect(find.text('이 번호의 통화기록이 없어요.'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('문자 미리보기를 누르면 선택한 원문을 열고 실행 실패를 안내한다', (tester) async {
    await prepare();
    await openApp(tester);
    await tester.tap(find.text('김민서').first);
    await tester.pumpAndSettle();
    final message = find.text('내일 산책 모임에서 만나요!');
    await tapInHistory(tester, message);
    expect(device.actions, ['message:42:7:01012345678']);

    device.failOpenMessage = true;
    await tapInHistory(tester, message);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(device.actions, hasLength(1));
    expect(tester.takeException(), isNull);
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
