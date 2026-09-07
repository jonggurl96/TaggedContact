import 'package:flutter/material.dart';

import '../controllers/contact_controller.dart';
import '../models/app_data.dart';
import '../utils/phone_utils.dart';
import '../widgets/common_widgets.dart';
import '../widgets/tag_editor.dart';
import 'calls_screen.dart';
import 'contacts_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});
  final ContactController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  AppScreen _screen = AppScreen.calls;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 기본 연락처 앱에서 저장하거나 권한을 변경하고 돌아오면 갱신한다.
    if (state == AppLifecycleState.resumed && widget.controller.storageReady) {
      widget.controller.refresh();
    }
  }

  Future<void> _addNumber() async {
    final number = await showDialog<String>(
      context: context,
      builder: (_) => const _NumberDialog(),
    );
    if (number != null && mounted) {
      await showTagEditor(context, widget.controller, number);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      body: ScreenBackground(
        controller: controller,
        screen: _screen,
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.tag_rounded,
                            color: Colors.white,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            '태그연락처',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                            ),
                          ),
                        ),
                        if (controller.refreshing)
                          const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else
                          IconButton(
                            tooltip: '새로고침',
                            onPressed: controller.loading
                                ? null
                                : () => controller.storageReady
                                      ? controller.refresh()
                                      : controller.initialize(),
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                      ],
                    ),
                  ),
                  if (controller.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: Text(
                        controller.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  Expanded(
                    child: controller.loading
                        ? const Center(child: CircularProgressIndicator())
                        : IndexedStack(
                            index: _screen.index,
                            children: [
                              CallsScreen(controller: controller),
                              ContactsScreen(controller: controller),
                              SettingsScreen(controller: controller),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton:
          _screen == AppScreen.settings || !controller.storageReady
          ? null
          : FloatingActionButton.extended(
              onPressed: _addNumber,
              icon: const Icon(Icons.add_rounded),
              label: const Text('번호에 태그'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _screen.index,
        onDestinationSelected: (index) {
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() => _screen = AppScreen.values[index]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_rounded),
            label: '통화기록',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: '연락처',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            selectedIcon: Icon(Icons.tune_rounded),
            label: '환경설정',
          ),
        ],
      ),
    );
  }
}

class _NumberDialog extends StatefulWidget {
  const _NumberDialog();

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  final _number = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, normalizePhone(_number.text));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('번호에 태그 붙이기'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _number,
        autofocus: true,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: '전화번호',
          hintText: '010-1234-5678',
        ),
        validator: (value) =>
            isUsablePhone(value ?? '') ? null : '올바른 전화번호를 입력해 주세요.',
        onFieldSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(onPressed: _submit, child: const Text('다음')),
    ],
  );
}
