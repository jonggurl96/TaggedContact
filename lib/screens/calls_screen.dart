import 'package:flutter/material.dart';

import '../controllers/contact_controller.dart';
import '../models/contact_models.dart';
import '../utils/phone_utils.dart';
import '../widgets/common_widgets.dart';
import '../widgets/contact_tile.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key, required this.controller});
  final ContactController controller;

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  String _query = '';
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final calls = controller.calls
        .where(
          (call) =>
              controller.matches(call.number, _query) &&
              (_filter != 1 || call.kind == CallKind.missed) &&
              (_filter != 2 || controller.tagsFor(call.number).isNotEmpty),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: CustomScrollView(
        key: const PageStorageKey('calls'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RECENT CONNECTIONS',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    '번호 너머,\n기억하고 싶은 관계.',
                    style: TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      letterSpacing: -1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 13),
                      const SizedBox(width: 5),
                      const Expanded(
                        child: Text(
                          '나의 태그는 이 기기에만 저장돼요',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF286653),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _Statistic(
                            label: '불러온 통화',
                            value: '${controller.calls.length}',
                          ),
                        ),
                        Container(width: 1, height: 34, color: Colors.white24),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _Statistic(
                            label: '태그로 기억한 번호',
                            value: '${controller.taggedCount}',
                          ),
                        ),
                        const Icon(
                          Icons.auto_awesome_outlined,
                          color: Color(0xFFCFDE9E),
                          size: 30,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: '이름, 전화번호, 태그 검색',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    textInputAction: TextInputAction.search,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final (index, label) in [
                        '전체',
                        '부재중',
                        '태그 있음',
                      ].indexed)
                        ChoiceChip(
                          label: Text(label),
                          selected: _filter == index,
                          onSelected: (_) => setState(() => _filter = index),
                          showCheckmark: false,
                        ),
                    ],
                  ),
                  if (!controller.permissions.calls)
                    PermissionCard(controller: controller, kind: 'calls'),
                  if (!controller.permissions.contacts)
                    PermissionCard(controller: controller, kind: 'contacts'),
                  if (controller.permissions.calls && calls.isEmpty)
                    EmptyState(
                      icon: Icons.history_rounded,
                      title: _query.isNotEmpty || _filter != 0
                          ? '일치하는 통화가 없어요'
                          : '아직 통화기록이 없어요',
                      description: _query.isNotEmpty || _filter != 0
                          ? '검색어나 필터를 바꾸거나 이전 통화를 더 불러와 보세요.'
                          : '기기에 통화기록이 생기면 여기에 표시돼요.\n번호에 태그를 먼저 붙여 보세요.',
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.builder(
              itemCount: calls.length,
              itemBuilder: (context, index) {
                final call = calls[index];
                final label = dayLabel(call.date);
                final newDay =
                    index == 0 || dayLabel(calls[index - 1].date) != label;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (newDay) SectionHeading(label),
                    ContactTile(
                      controller: controller,
                      number: call.number,
                      call: call,
                    ),
                  ],
                );
              },
            ),
          ),
          if (controller.hasMoreCalls)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: OutlinedButton(
                  onPressed: controller.loadingMore
                      ? null
                      : () => runAction(context, controller.loadMoreCalls),
                  child: Text(
                    controller.loadingMore ? '불러오는 중…' : '이전 통화 100건 더 보기',
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _Statistic extends StatelessWidget {
  const _Statistic({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: Color(0xFFD7E6DB), fontSize: 11),
      ),
      const SizedBox(height: 5),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 27,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
