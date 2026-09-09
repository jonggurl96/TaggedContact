import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/contact_controller.dart';
import '../models/app_data.dart';
import '../models/contact_models.dart';

Future<bool> runAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
    }
    return true;
  } catch (error) {
    final message = switch (error) {
      FormatException() => error.message,
      PlatformException() => error.message ?? '기기 작업을 완료하지 못했어요.',
      _ => '변경 내용을 저장하거나 작업을 완료하지 못했어요. 다시 시도해 주세요.',
    };
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
    return false;
  }
}

class ScreenBackground extends StatelessWidget {
  const ScreenBackground({
    super.key,
    required this.controller,
    required this.screen,
    required this.child,
  });
  final ContactController controller;
  final AppScreen screen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path = controller.settings.backgrounds[screen.name];
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Color(controller.settings.backgroundColor)),
        if (path != null)
          Image.file(
            File(path),
            fit: BoxFit.cover,
            cacheWidth: 1440,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        if (path != null)
          ColoredBox(
            color: Color(controller.settings.backgroundColor)
                .withValues(alpha: 0.78),
          ),
        child,
      ],
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 22, 2, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null)
          Text(trailing!, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant
            .withValues(alpha: 0.4),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class TagPill extends StatelessWidget {
  const TagPill(this.tag, {super.key});
  final String tag;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF0E6),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      '# $tag',
      style: TextStyle(
        fontSize: 11,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;

  // 부모 목록의 정렬과 관계없이 빈 목록 안내를 가로 중앙에 배치한다.
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: const Color(0xFFE5EBDF),
            child: Icon(
              icon,
              size: 30,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.6),
          ),
        ],
      ),
    ),
  );
}

class PermissionCard extends StatefulWidget {
  const PermissionCard({
    super.key,
    required this.controller,
    required this.kind,
    this.onChanged,
  });
  final ContactController controller;
  final String kind;
  final Future<void> Function()? onChanged;

  @override
  State<PermissionCard> createState() => _PermissionCardState();
}

class _PermissionCardState extends State<PermissionCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final (title, description, icon) = switch (widget.kind) {
      'contacts' => (
        '연락처를 연결해 주세요',
        '기기에 저장된 이름을 표시하고 이름과 태그로 검색할 수 있어요.',
        Icons.contacts_outlined,
      ),
      'sms' => (
        '문자도 함께 확인하세요',
        '문자 읽기를 허용하면 이 번호와 주고받은 최근 SMS를 보여드려요.',
        Icons.chat_bubble_outline_rounded,
      ),
      _ => (
        '통화기록을 연결해 주세요',
        '통화기록 읽기를 허용하면 최근 통화를 확인하고 번호에 태그를 붙일 수 있어요.',
        Icons.call_outlined,
      ),
    };
    // 권한 안내 카드가 부모 영역의 전체 너비를 채우도록 한다.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 12),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton(
                  onPressed: _busy || !widget.controller.device.isSupported
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          await runAction(context, () async {
                            await widget.controller.requestPermission(
                              widget.kind,
                            );
                            await widget.onChanged?.call();
                          });
                          if (mounted) setState(() => _busy = false);
                        },
                  child: Text(_busy ? '연결 중…' : '접근 허용'),
                ),
                TextButton(
                  onPressed: widget.controller.device.isSupported
                      ? () => runAction(
                          context,
                          widget.controller.device.openSettings,
                        )
                      : null,
                  child: const Text('기기 설정'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '허용하지 않아도 번호에 태그를 직접 추가할 수 있어요.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

IconData callIcon(CallKind kind) => switch (kind) {
  CallKind.incoming => Icons.call_received_rounded,
  CallKind.outgoing => Icons.call_made_rounded,
  CallKind.missed => Icons.call_missed_rounded,
  CallKind.rejected || CallKind.blocked => Icons.call_end_rounded,
  CallKind.other => Icons.call_outlined,
};
