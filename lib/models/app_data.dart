import 'contact_models.dart';

enum AppScreen {
  calls('통화기록'),
  contacts('연락처'),
  settings('환경설정');

  const AppScreen(this.label);
  final String label;
}

class AppSettings {
  // 문구 설정이 없는 기존 데이터에도 같은 기본 문구를 표시한다.
  static const defaultCallHeadline = '번호 너머,\n기억하고 싶은 관계.';

  const AppSettings({
    this.callHeadline = defaultCallHeadline,
    this.fontScale = 1,
    this.textColor = 0xFF243B35,
    this.backgroundColor = 0xFFF5F6F0,
    this.suggestionsEnabled = true,
    this.backgrounds = const {},
  });

  final String callHeadline;
  final double fontScale;
  final int textColor;
  final int backgroundColor;
  final bool suggestionsEnabled;
  final Map<String, String> backgrounds;

  AppSettings copyWith({
    String? callHeadline,
    double? fontScale,
    int? textColor,
    int? backgroundColor,
    bool? suggestionsEnabled,
    Map<String, String>? backgrounds,
  }) => AppSettings(
    callHeadline: callHeadline ?? this.callHeadline,
    fontScale: fontScale ?? this.fontScale,
    textColor: textColor ?? this.textColor,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    suggestionsEnabled: suggestionsEnabled ?? this.suggestionsEnabled,
    backgrounds: backgrounds ?? this.backgrounds,
  );

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    callHeadline: json['callHeadline'] as String? ?? defaultCallHeadline,
    fontScale: (json['fontScale'] as num? ?? 1).toDouble().clamp(0.85, 1.4),
    textColor: json['textColor'] as int? ?? 0xFF243B35,
    backgroundColor: json['backgroundColor'] as int? ?? 0xFFF5F6F0,
    suggestionsEnabled: json['suggestionsEnabled'] as bool? ?? true,
    backgrounds: Map<String, String>.from(json['backgrounds'] as Map? ?? {}),
  );

  Map<String, dynamic> toJson() => {
    'callHeadline': callHeadline,
    'fontScale': fontScale,
    'textColor': textColor,
    'backgroundColor': backgroundColor,
    'suggestionsEnabled': suggestionsEnabled,
    'backgrounds': backgrounds,
  };
}

class AppData {
  const AppData({
    this.tags = const {},
    this.settings = const AppSettings(),
    this.recordings = const {},
  });

  final Map<String, List<String>> tags;
  final AppSettings settings;
  final Map<String, List<LinkedRecording>> recordings;

  AppData copyWith({
    Map<String, List<String>>? tags,
    AppSettings? settings,
    Map<String, List<LinkedRecording>>? recordings,
  }) => AppData(
    tags: tags ?? this.tags,
    settings: settings ?? this.settings,
    recordings: recordings ?? this.recordings,
  );

  factory AppData.fromJson(Map<String, dynamic> json) {
    // 지원하지 않는 저장 형식은 덮어쓰지 않고 오류로 안내한다.
    if (json['version'] != 1) throw const FormatException('지원하지 않는 저장 형식');
    return AppData(
      tags: (json['tags'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, List<String>.from(value as List)),
      ),
      settings: AppSettings.fromJson(json['settings'] as Map<String, dynamic>),
      recordings: (json['recordings'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(
          key,
          (value as List)
              .map(
                (item) =>
                    LinkedRecording.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'tags': tags,
    'settings': settings.toJson(),
    'recordings': recordings.map(
      (key, value) =>
          MapEntry(key, value.map((item) => item.toJson()).toList()),
    ),
  };
}
