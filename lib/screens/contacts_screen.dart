import 'package:flutter/material.dart';

import '../controllers/contact_controller.dart';
import '../utils/phone_utils.dart';
import '../widgets/common_widgets.dart';
import '../widgets/contact_tile.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, required this.controller});
  final ContactController controller;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  String _query = '';
  bool _taggedOnly = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final contacts = controller.visibleContacts(
      _query,
      taggedOnly: _taggedOnly,
    );
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: CustomScrollView(
        key: const PageStorageKey('contacts'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MY PEOPLE',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    '이름에 기억을 더해요.',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '저장된 번호 ${controller.savedContactCount}개 · 태그로 기억한 번호 ${controller.taggedCount}개',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: '이름, 태그, 초성으로 찾아보세요',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    textInputAction: TextInputAction.search,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('전체'),
                        selected: !_taggedOnly,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _taggedOnly = false),
                      ),
                      ChoiceChip(
                        label: const Text('태그 있음'),
                        selected: _taggedOnly,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _taggedOnly = true),
                      ),
                    ],
                  ),
                  if (!controller.permissions.contacts)
                    PermissionCard(controller: controller, kind: 'contacts'),
                  if (contacts.isEmpty)
                    EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: _query.isNotEmpty || _taggedOnly
                          ? '검색 결과가 없어요'
                          : '새로운 기억을 시작해요',
                      description: _query.isNotEmpty || _taggedOnly
                          ? '다른 이름이나 태그로 검색해 보세요.'
                          : '연락처를 연결하거나 아래 버튼으로\n저장하지 않은 번호에도 태그를 붙여 보세요.',
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.builder(
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                final group = initialGroup(controller.titleFor(contact.number));
                final newGroup =
                    index == 0 ||
                    initialGroup(
                          controller.titleFor(contacts[index - 1].number),
                        ) !=
                        group;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (newGroup) SectionHeading(group),
                    ContactTile(controller: controller, number: contact.number),
                  ],
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
