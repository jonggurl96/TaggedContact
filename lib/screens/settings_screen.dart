import 'package:flutter/material.dart';

import '../controllers/contact_controller.dart';
import '../models/app_data.dart';
import '../widgets/common_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});
  final ContactController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double? _fontScale;
  bool _picking = false;

  Future<void> _background(AppScreen screen) async {
    setState(() => _picking = true);
    await runAction(context, () async {
      final path = await widget.controller.device.pickBackground();
      if (path != null) {
        await widget.controller.updateSettings(
          (settings) => settings.copyWith(
            backgrounds: {...settings.backgrounds, screen.name: path},
          ),
        );
      }
    });
    if (mounted) setState(() => _picking = false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final settings = controller.settings;
    return ListView(
      key: const PageStorageKey('settings'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        const Text(
          'MAKE IT YOURS',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          '나에게 편안한 화면.',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        const Text('작은 취향까지, 내 방식대로 설정하세요.', style: TextStyle(fontSize: 12)),
        const SectionHeading('글자와 색상'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '글자 크기',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${((_fontScale ?? settings.fontScale) * 100).round()}%',
                  ),
                ],
              ),
              Slider(
                value: _fontScale ?? settings.fontScale,
                min: 0.85,
                max: 1.4,
                divisions: 11,
                label: '${((_fontScale ?? settings.fontScale) * 100).round()}%',
                onChanged: controller.storageReady
                    ? (value) => setState(() => _fontScale = value)
                    : null,
                onChangeEnd: (value) async {
                  await runAction(
                    context,
                    () => controller.updateSettings(
                      (current) => current.copyWith(fontScale: value),
                    ),
                  );
                  if (mounted) setState(() => _fontScale = null);
                },
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(settings.backgroundColor),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '기억하고 싶은 사람, 김태그',
                      style: TextStyle(
                        color: Color(settings.textColor),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [TagPill('동네친구'), TagPill('함께걷기')],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                '글자 색상',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _ColorChoices(
                values: const {
                  '숲': 0xFF243B35,
                  '먹색': 0xFF242424,
                  '남색': 0xFF293C59,
                  '밤색': 0xFF573C32,
                  '자주': 0xFF59334C,
                },
                selected: settings.textColor,
                onChanged: controller.storageReady
                    ? (color) => runAction(
                        context,
                        () => controller.updateSettings(
                          (current) => current.copyWith(textColor: color),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 22),
              const Text(
                '배경 색상',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _ColorChoices(
                values: const {
                  '아이보리': 0xFFF5F6F0,
                  '화이트': 0xFFFAFAFA,
                  '하늘': 0xFFEDF3F8,
                  '복숭아': 0xFFFCF0E8,
                  '라일락': 0xFFF4EFF8,
                },
                selected: settings.backgroundColor,
                onChanged: controller.storageReady
                    ? (color) => runAction(
                        context,
                        () => controller.updateSettings(
                          (current) => current.copyWith(backgroundColor: color),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
        const SectionHeading('화면별 배경화면'),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              for (final screen in AppScreen.values)
                ListTile(
                  leading: Icon(switch (screen) {
                    AppScreen.calls => Icons.history_rounded,
                    AppScreen.contacts => Icons.people_outline_rounded,
                    AppScreen.settings => Icons.tune_rounded,
                  }),
                  title: Text(screen.label),
                  subtitle: Text(
                    settings.backgrounds.containsKey(screen.name)
                        ? '내 사진 · 눌러서 변경'
                        : '기본 배경 · 눌러서 사진 선택',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: _picking || !controller.storageReady
                      ? null
                      : () => _background(screen),
                  trailing: settings.backgrounds.containsKey(screen.name)
                      ? IconButton(
                          tooltip: '${screen.label} 배경 삭제',
                          onPressed: () => runAction(
                            context,
                            () => controller.updateSettings((current) {
                              final next = {...current.backgrounds}
                                ..remove(screen.name);
                              return current.copyWith(backgrounds: next);
                            }),
                          ),
                          icon: const Icon(Icons.close_rounded),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  '25MB 이하의 사진을 선택하세요. 글자가 잘 보이도록 사진 위에 배경 색을 은은하게 더해요.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SectionHeading('태그 입력'),
        SurfaceCard(
          padding: const EdgeInsets.all(4),
          child: SwitchListTile.adaptive(
            title: const Text('저장된 태그 추천'),
            subtitle: const Text(
              '입력한 글자와 일치하는 내 태그를 보여줘요.',
              style: TextStyle(fontSize: 12),
            ),
            value: settings.suggestionsEnabled,
            onChanged: controller.storageReady
                ? (value) => runAction(
                    context,
                    () => controller.updateSettings(
                      (current) => current.copyWith(suggestionsEnabled: value),
                    ),
                  )
                : null,
          ),
        ),
        const SectionHeading('기기 연결'),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              for (final (label, granted) in [
                ('연락처', controller.permissions.contacts),
                ('통화기록', controller.permissions.calls),
                ('문자', controller.permissions.sms),
              ])
                ListTile(
                  dense: true,
                  leading: Icon(
                    granted
                        ? Icons.check_circle_outline_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                  ),
                  title: Text(label),
                  trailing: Text(
                    granted ? '연결됨' : '연결 안 됨',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: controller.device.isSupported
                        ? () =>
                              runAction(context, controller.device.openSettings)
                        : null,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('기기에서 권한 관리'),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline_rounded, size: 17),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '태그와 설정은 이 기기에만 저장됩니다.\n앱을 삭제하거나 데이터를 지우면 함께 삭제됩니다.',
                style: TextStyle(fontSize: 12, height: 1.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('태그연락처 1.0.0', style: TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _ColorChoices extends StatelessWidget {
  const _ColorChoices({
    required this.values,
    required this.selected,
    required this.onChanged,
  });
  final Map<String, int> values;
  final int selected;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: values.entries
        .map(
          (entry) => Semantics(
            button: true,
            selected: selected == entry.value,
            label: entry.key,
            child: Tooltip(
              message: entry.key,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: onChanged == null ? null : () => onChanged!(entry.value),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color(entry.value),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected == entry.value
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFFD5DAD0),
                      width: selected == entry.value ? 3 : 1,
                    ),
                  ),
                  child: selected == entry.value
                      ? Icon(
                          Icons.check_rounded,
                          color: Color(entry.value).computeLuminance() < 0.4
                              ? Colors.white
                              : const Color(0xFF286653),
                        )
                      : null,
                ),
              ),
            ),
          ),
        )
        .toList(),
  );
}
