import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_data.dart';
import '../models/contact_models.dart';

class DeviceService {
  static const _channel = MethodChannel('tagged_contact/device');

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<AppData> load() async {
    final json = await _channel.invokeMethod<String>('loadState');
    return json == null
        ? const AppData()
        : AppData.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> save(AppData data) =>
      _channel.invokeMethod('saveState', {'json': jsonEncode(data.toJson())});

  Future<DevicePermissions> permissions() async => DevicePermissions.fromMap(
    await _channel.invokeMapMethod<Object?, Object?>('permissions') ?? {},
  );

  Future<void> requestPermission(String kind) =>
      _channel.invokeMethod('requestPermission', {'kind': kind});

  Future<List<PhoneContact>> contacts() async {
    final result = await _channel.invokeListMethod<Object?>('contacts') ?? [];
    return result.map((item) => PhoneContact.fromMap(item as Map)).toList();
  }

  Future<List<PhoneCall>> calls({int offset = 0}) async {
    final result =
        await _channel.invokeListMethod<Object?>('calls', {'offset': offset}) ??
        [];
    return result.map((item) => PhoneCall.fromMap(item as Map)).toList();
  }

  Future<List<PhoneMessage>> messages(String number) async {
    final result =
        await _channel.invokeListMethod<Object?>('messages', {
          'number': number,
        }) ??
        [];
    return result.map((item) => PhoneMessage.fromMap(item as Map)).toList();
  }

  Future<List<PhoneCall>> history(String number, {int offset = 0}) async {
    final result =
        await _channel.invokeListMethod<Object?>('history', {
          'number': number,
          'offset': offset,
        }) ??
        [];
    return result.map((item) => PhoneCall.fromMap(item as Map)).toList();
  }

  Future<void> dial(String number) =>
      _channel.invokeMethod('dial', {'number': number});

  Future<void> composeMessage(String number) =>
      _channel.invokeMethod('composeMessage', {'number': number});

  Future<void> insertContact(String number) =>
      _channel.invokeMethod('insertContact', {'number': number});

  Future<void> openSettings() => _channel.invokeMethod('openSettings');

  Future<String?> pickBackground() =>
      _channel.invokeMethod<String>('pickBackground');

  Future<LinkedRecording?> pickRecording() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'pickRecording',
    );
    return result == null
        ? null
        : LinkedRecording(
            uri: result['uri'] as String,
            name: result['name'] as String,
            addedAt: DateTime.now(),
          );
  }

  Future<void> playRecording(String uri) =>
      _channel.invokeMethod('playRecording', {'uri': uri});
}
