import 'package:flutter/material.dart';

import 'app.dart';
import 'controllers/contact_controller.dart';
import 'services/device_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 기기 데이터와 화면 상태의 수명을 앱 전체에서 공유한다.
  final controller = ContactController(DeviceService());
  runApp(TaggedContactApp(controller: controller));
  controller.initialize();
}
