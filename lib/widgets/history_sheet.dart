import 'package:flutter/material.dart';

import '../controllers/contact_controller.dart';
import '../models/contact_models.dart';
import '../utils/phone_utils.dart';
import 'common_widgets.dart';
import 'tag_editor.dart';

Future<void> showHistorySheet(
  BuildContext context,
  ContactController controller,
  PhoneCall call,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _HistorySheet(controller: controller, call: call),
);

class _HistorySheet extends StatefulWidget {
  const _HistorySheet({required this.controller, required this.call});
  final ContactController controller;
  final PhoneCall call;

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet>
    with WidgetsBindingObserver {
  List<PhoneCall> _calls = [];
  List<PhoneMessage> _messages = [];
  bool _loading = true;
  bool _more = false;
  bool _loadingMore = false;
  bool _picking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading && !_loadingMore) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final device = widget.controller.device;
      final permissions = await device.permissions();
      final usable = isUsablePhone(widget.call.number);
      final result = await Future.wait<Object>([
        usable && permissions.calls
            ? device.history(widget.call.number)
            : Future.value(<PhoneCall>[]),
        usable && permissions.sms
            ? device.messages(widget.call.number)
            : Future.value(<PhoneMessage>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _calls = result[0] as List<PhoneCall>;
        // 표시제한 번호끼리는 같은 사람으로 묶지 않고 선택한 통화만 보여준다.
        if (!usable && permissions.calls) _calls = [widget.call];
        _messages = result[1] as List<PhoneMessage>;
        _more = usable && _calls.length == 100;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _calls = [];
          _messages = [];
          _error = '기록을 불러오지 못했어요. 권한을 확인하고 다시 시도해 주세요.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    await runAction(context, () async {
      final next = await widget.controller.device.history(
        widget.call.number,
        offset: _calls.length,
      );
      if (!mounted) return;
      setState(() {
        final ids = _calls.map((call) => call.id).toSet();
        _calls.addAll(next.where((call) => ids.add(call.id)));
        _more = next.length == 100;
      });
    });
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _addRecording() async {
    setState(() => _picking = true);
    await runAction(context, () async {
      final recording = await widget.controller.device.pickRecording();
      if (recording != null) {
        await widget.controller.addRecording(widget.call.number, recording);
      }
    });
    if (mounted) setState(() => _picking = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final number = widget.call.number;
      final usable = isUsablePhone(number);
      final recordings = controller.recordingsFor(number);
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 12, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '이 번호와의 기록',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: '기록 새로고침',
                    onPressed: _loading || _loadingMore ? null : _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  Text(
                    controller.titleFor(number),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(displayPhone(number)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: controller
                        .tagsFor(number)
                        .map(TagPill.new)
                        .toList(),
                  ),
                  if (usable)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                showTagEditor(context, controller, number),
                            icon: const Icon(Icons.sell_outlined, size: 18),
                            label: const Text('태그 편집'),
                          ),
                          IconButton(
                            tooltip: '전화하기',
                            onPressed: () => runAction(
                              context,
                              () => controller.device.dial(number),
                            ),
                            icon: const Icon(Icons.call_outlined),
                          ),
                          IconButton(
                            tooltip: '문자보내기',
                            onPressed: () => runAction(
                              context,
                              () => controller.device.composeMessage(number),
                            ),
                            icon: const Icon(Icons.chat_bubble_outline_rounded),
                          ),
                          if (!controller.contactFor(number).isSaved)
                            IconButton(
                              tooltip: '연락처 저장',
                              onPressed: () => runAction(
                                context,
                                () => controller.device.insertContact(number),
                              ),
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                            ),
                        ],
                      ),
                    ),
                  const SectionHeading('통화기록'),
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (!controller.permissions.calls)
                    PermissionCard(
                      controller: controller,
                      kind: 'calls',
                      onChanged: _load,
                    )
                  else if (!_loading && _error == null && _calls.isEmpty)
                    const Text('이 번호의 통화기록이 없어요.')
                  else if (!_loading)
                    ..._calls.map(
                      (call) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFEAF0E6),
                          child: Icon(callIcon(call.kind), size: 20),
                        ),
                        title: Text(
                          call.kind.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${dayLabel(call.date)} ${timeLabel(call.date)} · ${durationLabel(call.duration)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  if (_more && !_loading && controller.permissions.calls)
                    TextButton(
                      onPressed: _loadingMore ? null : _loadMore,
                      child: Text(_loadingMore ? '불러오는 중…' : '이전 통화 더 보기'),
                    ),
                  if (usable) ...[
                    const SectionHeading('통화 녹음'),
                    const Text(
                      '기기의 녹음 파일을 직접 연결해 주세요.\n연결한 파일은 기본 재생 앱으로 열립니다.',
                      style: TextStyle(fontSize: 12, height: 1.6),
                    ),
                    const SizedBox(height: 10),
                    for (final recording in recordings)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.play_circle_outline_rounded),
                        title: Text(
                          recording.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${dayLabel(recording.addedAt)} 연결',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () => runAction(
                          context,
                          () => controller.device.playRecording(recording.uri),
                        ),
                        trailing: IconButton(
                          tooltip: '녹음 연결 해제',
                          icon: const Icon(Icons.link_off_rounded),
                          onPressed: () => runAction(
                            context,
                            () => controller.removeRecording(
                              number,
                              recording.uri,
                            ),
                          ),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: _picking || !controller.storageReady
                          ? null
                          : _addRecording,
                      icon: const Icon(Icons.audio_file_outlined, size: 18),
                      label: Text(_picking ? '파일 선택 중…' : '녹음 파일 연결'),
                    ),
                    const SectionHeading('문자 미리보기', trailing: '최근 SMS 50건'),
                    if (!controller.permissions.sms)
                      PermissionCard(
                        controller: controller,
                        kind: 'sms',
                        onChanged: _load,
                      )
                    else if (!_loading && _error == null && _messages.isEmpty)
                      const Text(
                        '표시할 수 있는 SMS가 없어요.',
                        style: TextStyle(fontSize: 13),
                      )
                    else if (!_loading)
                      ..._messages.map(
                        (message) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SurfaceCard(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${message.incoming ? '받은 문자' : '보낸 문자'} · ${dayLabel(message.date)} ${timeLabel(message.date)}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  message.body,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'Android에서 보호한 문자는 표시되지 않을 수 있어요. MMS·RCS와 전체 내용은 기본 문자 앱에서 확인하세요.',
                      style: TextStyle(fontSize: 11, height: 1.5),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
