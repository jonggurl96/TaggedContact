import 'package:flutter/material.dart';

import '../controllers/contact_controller.dart';
import '../models/contact_models.dart';
import '../utils/phone_utils.dart';
import 'common_widgets.dart';
import 'history_sheet.dart';
import 'tag_editor.dart';

class ContactTile extends StatelessWidget {
  const ContactTile({
    super.key,
    required this.controller,
    required this.number,
    this.call,
  });
  final ContactController controller;
  final String number;
  final PhoneCall? call;

  @override
  Widget build(BuildContext context) {
    final title = controller.titleFor(number);
    final tags = controller.tagsFor(number);
    final saved = controller.contactFor(number).isSaved;
    final usable = isUsablePhone(number);
    final missed = call?.kind == CallKind.missed;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surface.withValues(alpha: 0.96),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => call != null
              ? showHistorySheet(context, controller, call!)
              : showTagEditor(context, controller, number),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: missed
                          ? const Color(0xFFFBEAE1)
                          : const Color(0xFFE6EDE3),
                      child: initialGroup(title) == '#'
                          ? Icon(
                              usable
                                  ? Icons.person_outline_rounded
                                  : Icons.phone_locked_outlined,
                              color: colors.primary,
                            )
                          : Text(
                              title.characters.first,
                              style: TextStyle(
                                fontSize: 18,
                                color: colors.primary,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              color: missed ? const Color(0xFFB34E32) : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (call != null)
                            Wrap(
                              spacing: 5,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Icon(
                                  callIcon(call!.kind),
                                  size: 13,
                                  color: missed
                                      ? const Color(0xFFB34E32)
                                      : colors.primary,
                                ),
                                Text(
                                  '${call!.kind.label} · ${timeLabel(call!.date)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (call!.duration > 0)
                                  Text(
                                    '· ${durationLabel(call!.duration)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                              ],
                            )
                          else
                            Text(
                              displayPhone(number),
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Icon(Icons.chevron_right_rounded, size: 20),
                    ),
                  ],
                ),
                if (tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        ...tags.take(3).map(TagPill.new),
                        if (tags.length > 3) TagPill('+${tags.length - 3}'),
                      ],
                    ),
                  ),
                if (usable)
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: controller.storageReady
                            ? () => showTagEditor(context, controller, number)
                            : null,
                        icon: const Icon(Icons.sell_outlined, size: 16),
                        label: const Text('태그', style: TextStyle(fontSize: 12)),
                      ),
                      const Spacer(),
                      if (call != null && !saved)
                        IconButton(
                          tooltip: '연락처 저장',
                          onPressed: () => runAction(
                            context,
                            () => controller.device.insertContact(number),
                          ),
                          icon: const Icon(
                            Icons.person_add_alt_1_outlined,
                            size: 20,
                          ),
                        ),
                      IconButton(
                        tooltip: '전화하기',
                        onPressed: () => runAction(
                          context,
                          () => controller.device.dial(number),
                        ),
                        icon: const Icon(Icons.call_outlined, size: 20),
                      ),
                      IconButton(
                        tooltip: '문자보내기',
                        onPressed: () => runAction(
                          context,
                          () => controller.device.composeMessage(number),
                        ),
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                if (!usable)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      '번호가 표시되지 않아 태그를 추가할 수 없어요.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
