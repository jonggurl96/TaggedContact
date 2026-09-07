import '../utils/phone_utils.dart';

class PhoneContact {
  const PhoneContact({required this.number, this.name = '', bool? saved})
    : isSaved = saved ?? (name != '');

  final String number;
  final String name;
  String get key => normalizePhone(number);
  final bool isSaved;

  factory PhoneContact.fromMap(Map<Object?, Object?> map) => PhoneContact(
    number: map['number'] as String? ?? '',
    name: map['name'] as String? ?? '',
    saved: true,
  );
}

enum CallKind {
  incoming('수신', 1),
  outgoing('발신', 2),
  missed('부재중', 3),
  rejected('수신 거절', 5),
  blocked('차단', 6),
  other('기타', 0);

  const CallKind(this.label, this.code);
  final String label;
  final int code;
}

class PhoneCall {
  const PhoneCall({
    required this.id,
    required this.number,
    required this.date,
    required this.kind,
    this.duration = 0,
  });

  final String id;
  final String number;
  final DateTime date;
  final CallKind kind;
  final int duration;
  String get key => normalizePhone(number);

  factory PhoneCall.fromMap(Map<Object?, Object?> map) => PhoneCall(
    id: map['id'].toString(),
    number: map['number'] as String? ?? '',
    date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
    kind: CallKind.values.firstWhere(
      (kind) => kind.code == map['type'],
      orElse: () => CallKind.other,
    ),
    duration: map['duration'] as int? ?? 0,
  );
}

class PhoneMessage {
  const PhoneMessage({
    required this.number,
    required this.body,
    required this.date,
    required this.incoming,
  });

  final String number;
  final String body;
  final DateTime date;
  final bool incoming;

  factory PhoneMessage.fromMap(Map<Object?, Object?> map) => PhoneMessage(
    number: map['number'] as String? ?? '',
    body: map['body'] as String? ?? '',
    date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
    incoming: map['type'] == 1,
  );
}

class LinkedRecording {
  const LinkedRecording({
    required this.uri,
    required this.name,
    required this.addedAt,
  });

  final String uri;
  final String name;
  final DateTime addedAt;

  factory LinkedRecording.fromJson(Map<String, dynamic> json) =>
      LinkedRecording(
        uri: json['uri'] as String,
        name: json['name'] as String,
        addedAt: DateTime.parse(json['addedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
    'uri': uri,
    'name': name,
    'addedAt': addedAt.toIso8601String(),
  };
}

class DevicePermissions {
  const DevicePermissions({
    this.contacts = false,
    this.calls = false,
    this.sms = false,
  });

  final bool contacts;
  final bool calls;
  final bool sms;

  factory DevicePermissions.fromMap(Map<Object?, Object?> map) =>
      DevicePermissions(
        contacts: map['contacts'] == true,
        calls: map['calls'] == true,
        sms: map['sms'] == true,
      );
}
