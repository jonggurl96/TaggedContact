import 'package:characters/characters.dart';

// 국내 번호와 +82 국제 표기를 같은 태그 저장 키로 연결한다.
String normalizePhone(String phone) {
  var value = phone.trim().replaceAll(RegExp(r'[\s().-]'), '');
  if (value.startsWith('0082')) value = '+82${value.substring(4)}';
  if (value.startsWith('+82')) {
    final national = value.substring(3);
    value = national.startsWith('0') ? national : '0$national';
  }
  return value;
}

bool isUsablePhone(String phone) =>
    RegExp(r'^\+?[0-9]{2,15}$').hasMatch(normalizePhone(phone));

String displayPhone(String phone) {
  final value = normalizePhone(phone);
  if (value.isEmpty) return '발신번호 표시제한';
  if (value.startsWith('010') && value.length == 11) {
    return '${value.substring(0, 3)}-${value.substring(3, 7)}-${value.substring(7)}';
  }
  return phone;
}

String initialGroup(String text) {
  final value = text.trim();
  if (value.isEmpty) return '#';
  final code = value.runes.first;
  if (code >= 0xAC00 && code <= 0xD7A3) {
    const initials = [
      'ㄱ',
      'ㄲ',
      'ㄴ',
      'ㄷ',
      'ㄸ',
      'ㄹ',
      'ㅁ',
      'ㅂ',
      'ㅃ',
      'ㅅ',
      'ㅆ',
      'ㅇ',
      'ㅈ',
      'ㅉ',
      'ㅊ',
      'ㅋ',
      'ㅌ',
      'ㅍ',
      'ㅎ',
    ];
    return initials[(code - 0xAC00) ~/ 588];
  }
  final first = value.characters.first.toUpperCase();
  if (RegExp(r'^[A-Zㄱ-ㅎ]$').hasMatch(first)) return first;
  return '#';
}

String initialsOf(String text) => text.characters.map(initialGroup).join();

String? validateTag(String value) {
  if (value.trim().isEmpty) return '태그를 입력해 주세요.';
  if (value.trim().characters.length > 10) return '태그는 최대 10자까지 입력할 수 있어요.';
  return null;
}

String dayLabel(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final current = DateTime(today.year, today.month, today.day);
  if (day == current) return '오늘';
  if (day == current.subtract(const Duration(days: 1))) return '어제';
  return '${date.year == today.year ? '' : '${date.year}년 '}${date.month}월 ${date.day}일';
}

String timeLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String durationLabel(int seconds) {
  if (seconds <= 0) return '연결 안 됨';
  final minutes = seconds ~/ 60;
  return minutes == 0 ? '$seconds초' : '$minutes분 ${seconds % 60}초';
}
