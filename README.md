# 태그연락처

이름만으로 기억하기 어려운 연락처와 저장하지 않은 번호를 태그로 관리하는 Android용 Flutter 앱입니다. 서버와 회원가입 없이 동작합니다.

## 구현 기능

- **통화기록**: 시작 화면, 최신순 목록, 전체·부재중·태그 있음 필터, 검색, 100건 단위 추가 조회.
- **연락처**: 기기 연락처와 태그를 붙인 미등록 번호를 함께 표시. 저장된 이름 → 첫 태그 → 번호 순서로 표시 이름을 결정하고 초성으로 그룹화합니다. 이름·태그·번호·초성 검색을 지원합니다.
- **태그 편집**: 연락처 팝업에서 직접 수정·삭제·드래그 순서 변경. 마지막 빈 입력칸으로 계속 추가하고, 저장 버튼을 누르면 입력 중인 마지막 태그도 저장합니다. 같은 번호의 중복 태그는 허용하지 않습니다.
- **10자 제한**: 한글·조합 문자·가족 이모지처럼 사용자에게 한 글자로 보이는 문자를 기준으로 계산합니다.
- **기본 앱 연결**: 전화는 다이얼 화면, 문자는 작성 화면, 연락처 저장은 기본 연락처 앱을 엽니다. 자동 발신·전송하지 않습니다.
- **기록 팝업**: 선택한 번호의 통화기록, 최근 SMS 50건의 미리보기, 사용자가 연결한 통화 녹음 파일을 표시합니다. 녹음은 기본 재생 앱에서 엽니다.
- **환경설정**: 화면별 사진 배경, 글자 크기 85~140%, 글자·배경 색상, 기존 태그 자동 추천 설정. 기기의 접근성 글자 배율도 함께 적용합니다.

## 실행

현재 프로젝트는 **Android 플랫폼만** 구성되어 있습니다. Flutter 3.47.2 / Dart 3.13.2 이상과 Android SDK, JDK 17 이상이 필요합니다. 이 환경의 Gradle 빌드는 JDK 25에서 확인했습니다.

```powershell
flutter pub get
flutter devices
flutter run -d <Android 기기 ID>
```

Flutter가 PATH에 없다면 설치 위치의 `bin/flutter.bat`을 실행합니다. 개발 APK는 다음 명령으로 생성합니다.

```powershell
flutter build apk --debug
```

생성 위치: `build/app/outputs/flutter-apk/app-debug.apk`

첫 화면에서 연락처·통화기록 접근을 각각 허용합니다. 문자 권한은 통화 상세의 문자 영역에서 선택합니다. 권한을 거부해도 **번호에 태그** 버튼으로 직접 관리할 수 있습니다. 다시 요청해도 권한 창이 나타나지 않으면 **기기 설정**에서 변경할 수 있습니다.

## 저장과 권한

- 태그·설정·녹음 연결 정보는 앱 전용 `files/tagged_contact.json`에 저장합니다. Android `AtomicFile`과 직렬화한 쓰기로 중단된 저장과 동시 변경을 처리합니다.
- `010…`, `+82 10…`, `0082 10…`는 같은 번호로 처리합니다. 다른 국가 코드는 유지합니다. 번호 끝자리만으로 연락처를 합치지 않습니다.
- 연락처·통화기록·문자 본문은 로컬 JSON에 복사하지 않고 권한이 있을 때 기기의 제공자를 조회합니다. 권한 철회 후 화면의 기기 데이터도 갱신합니다.
- 선택한 배경 이미지는 25MB까지 가져올 수 있으며 긴 변 1920px 이하로 줄여 앱 전용 폴더에 저장합니다. 전체 사진·저장소 권한 없이 시스템 문서 선택기를 사용합니다.
- 통화 녹음은 시스템/제조사 앱의 비공개 저장소에 자동 접근하지 않습니다. 사용자가 문서 선택기에서 지정한 오디오의 읽기 권한을 보관합니다. 연결 해제는 원본 파일을 삭제하지 않습니다.
- 태그와 설정은 클라우드 백업 및 기기 이전에서 제외합니다. 앱 삭제나 앱 데이터 삭제 시 복구되지 않습니다.
- 요청 권한은 `READ_CONTACTS`, `READ_CALL_LOG`, `READ_SMS`입니다. 연락처 쓰기·직접 발신·문자 전송·마이크 권한은 필요하지 않습니다.
- MMS, RCS, 메신저 내용은 SMS 조회 대상이 아닙니다. 전체 내용은 기본 문자 앱에서 확인합니다.
- Android가 보호 대상으로 분류한 SMS는 읽기 권한이 있어도 기본 문자 앱에서만 보일 수 있습니다. 이 앱은 시스템의 조회 제한을 따릅니다.
- Google Play 배포 전에는 통화기록·SMS 제한 권한의 앱 자격 또는 예외 승인을 검토해야 합니다. 이 앱은 기본 전화/SMS 앱 역할을 구현하지 않습니다. 현재 release 서명 설정도 Flutter 기본 개발용 설정이므로 실제 배포 시 별도의 서명이 필요합니다.

## 구조

```text
lib/
  main.dart                     # 진입점
  app.dart                      # 한국어 및 앱 테마
  models/                       # 연락처, 통화, 태그 저장 형식, 설정
  controllers/                  # 검색, 정렬, 상태 및 저장 조정
  services/                     # Android 플랫폼 채널
  screens/                      # 통화기록, 연락처, 환경설정
  widgets/                      # 목록, 태그 편집, 통화 상세, 공통 UI
  utils/                        # 번호 정규화, 초성, 날짜, 태그 검증
android/app/src/main/kotlin/.../
  DeviceBridge.kt               # 권한, 기기 조회, 원자적 저장, 기본 앱 연결
test/                           # 모델·컨트롤러·화면 테스트
integration_test/               # 실제 Android 플랫폼 연동 테스트
tool/prepare_android_test.ps1   # 테스트 전용 에뮬레이터 데이터 준비
```

상태 관리는 Flutter `ChangeNotifier`를 사용합니다. Android 연동은 기본 API와 Flutter `MethodChannel`로 구현하여 별도 기기 연동 플러그인을 추가하지 않았습니다. `flutter_localizations`는 한국어 UI, `characters`는 정확한 태그 길이 검증에 사용합니다. `integration_test`는 Flutter SDK의 개발용 테스트 패키지입니다.

## 검증

```powershell
flutter analyze
flutter test
```

실제 저장·연락처·번호별 통화 페이지·SMS 조회를 확인하는 통합 테스트는 **테스트 전용 에뮬레이터**에서 실행합니다. 준비 스크립트는 테스트 번호 `01090000001`, `01090000002`의 통화와 `tagged_contact_test` 계정의 연락처를 다시 생성하므로 개인용 에뮬레이터에는 실행하지 마세요. `-read-only -no-snapshot` 옵션으로 시작한 임시 에뮬레이터를 권장합니다.

```powershell
flutter build apk --debug
adb -s emulator-5580 root
adb -s emulator-5580 install -r -g build/app/outputs/flutter-apk/app-debug.apk
./tool/prepare_android_test.ps1 -Serial emulator-5580
flutter test integration_test/device_test.dart -d emulator-5580
```

통합 테스트는 기존 앱 JSON을 마지막에 복원합니다. 화면 확인용 PNG는 테스트 앱의 캐시에 `tagged_home.png`, `tagged_contacts.png`, `tagged_settings.png`로 남깁니다.

Android 37 에뮬레이터는 외부에서 삽입한 합성 SMS를 보호 대상으로 분류합니다. 이 경우 `--dart-define=SMS_FIXTURE_RESTRICTED=true`를 통합 테스트 명령에 추가하여 해당 메시지가 앱에 노출되지 않는지 검증합니다. 일반 문자 미리보기의 화면 동작은 위젯 테스트로 별도 검증합니다.
