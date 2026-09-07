import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/contact_controller.dart';
import '../utils/phone_utils.dart';
import 'common_widgets.dart';

Future<void> showTagEditor(
  BuildContext context,
  ContactController controller,
  String number,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => TagEditor(controller: controller, number: number),
);

class TagEditor extends StatefulWidget {
  const TagEditor({super.key, required this.controller, required this.number});
  final ContactController controller;
  final String number;

  @override
  State<TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<TagEditor> {
  late final List<TextEditingController> _tags;
  final _newTag = TextEditingController();
  final _retired = <TextEditingController>[];
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tags = widget.controller
        .tagsFor(widget.number)
        .map((tag) => TextEditingController(text: tag))
        .toList();
  }

  @override
  void dispose() {
    for (final tag in [..._tags, ..._retired]) {
      tag.dispose();
    }
    _newTag.dispose();
    super.dispose();
  }

  void _append([String? suggestion]) {
    final value = (suggestion ?? _newTag.text).trim();
    final error = validateTag(value);
    if (error != null || _tags.any((tag) => tag.text.trim() == value)) {
      setState(() => _error = error ?? '이미 추가한 태그예요.');
      return;
    }
    setState(() {
      _tags.add(TextEditingController(text: value));
      _newTag.clear();
      _error = null;
    });
  }

  Future<void> _save() async {
    final values = _tags.map((tag) => tag.text.trim()).toList();
    if (_newTag.text.trim().isNotEmpty) values.add(_newTag.text.trim());
    for (final tag in values) {
      final error = validateTag(tag);
      if (error != null) {
        setState(() => _error = error);
        return;
      }
    }
    if (values.toSet().length != values.length) {
      setState(() => _error = '같은 태그는 한 번만 추가할 수 있어요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await runAction(
      context,
      () => widget.controller.saveTags(widget.number, values),
      success: '태그를 저장했어요.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.controller.contactFor(widget.number);
    final query = _newTag.text.trim().toLowerCase();
    final suggestions =
        widget.controller.settings.suggestionsEnabled && query.isNotEmpty
        ? widget.controller.allTags
              .where(
                (tag) =>
                    tag.toLowerCase().contains(query) &&
                    !_tags.any((existing) => existing.text.trim() == tag),
              )
              .take(8)
              .toList()
        : <String>[];
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.82,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 12, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '연락처 · 태그',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name.trim().isNotEmpty
                            ? contact.name
                            : displayPhone(widget.number),
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (contact.name.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(displayPhone(widget.number)),
                        ),
                      const SizedBox(height: 22),
                      const Text(
                        '나만의 태그',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '직접 고치거나 오른쪽 손잡이를 끌어 순서를 바꾸세요.\n저장된 이름이 없으면 첫 번째 태그가 이름이 돼요.',
                        style: TextStyle(fontSize: 12, height: 1.6),
                      ),
                      const SizedBox(height: 16),
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: _tags.length,
                        // 편집 중인 입력창의 커서 오버레이가 드래그를 따라가지 않게 한다.
                        onReorderStart: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                        onReorderItem: (oldIndex, newIndex) {
                          if (_saving) return;
                          setState(() {
                            _tags.insert(newIndex, _tags.removeAt(oldIndex));
                          });
                        },
                        itemBuilder: (context, index) => Padding(
                          key: ObjectKey(_tags[index]),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _tags[index],
                                  enabled: !_saving,
                                  maxLength: 10,
                                  maxLengthEnforcement: MaxLengthEnforcement
                                      .truncateAfterCompositionEnds,
                                  decoration: InputDecoration(
                                    labelText: '${index + 1}번째 태그',
                                    prefixText: '# ',
                                    counterText: '',
                                  ),
                                  onChanged: (_) =>
                                      setState(() => _error = null),
                                ),
                              ),
                              IconButton(
                                tooltip: '태그 삭제',
                                onPressed: _saving
                                    ? null
                                    : () => setState(() {
                                        _retired.add(_tags.removeAt(index));
                                      }),
                                icon: const Icon(
                                  Icons.remove_circle_outline_rounded,
                                ),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                enabled: !_saving,
                                child: const SizedBox(
                                  width: 36,
                                  height: 52,
                                  child: Tooltip(
                                    message: '끌어서 순서 변경',
                                    child: Icon(Icons.drag_handle_rounded),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      TextField(
                        controller: _newTag,
                        enabled: !_saving,
                        maxLength: 10,
                        maxLengthEnforcement:
                            MaxLengthEnforcement.truncateAfterCompositionEnds,
                        decoration: InputDecoration(
                          labelText: '새 태그',
                          hintText: '예: 동네친구, 거래처',
                          prefixText: '# ',
                          suffixIcon: IconButton(
                            tooltip: '태그 추가',
                            onPressed: _saving ? null : _append,
                            icon: const Icon(Icons.add_circle_outline_rounded),
                          ),
                        ),
                        onChanged: (_) => setState(() => _error = null),
                        onSubmitted: (_) => _append(),
                      ),
                      if (suggestions.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          children: suggestions
                              .map(
                                (tag) => ActionChip(
                                  label: Text('# $tag'),
                                  onPressed: _saving
                                      ? null
                                      : () => _append(tag),
                                ),
                              )
                              .toList(),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving || !widget.controller.storageReady
                          ? null
                          : _save,
                      child: Text(_saving ? '저장 중…' : '태그 저장'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
