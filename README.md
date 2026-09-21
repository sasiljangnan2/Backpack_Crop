# Backpack

그룹 여행 일정과 공동 경비를 관리하기 위한 Flutter 모바일 앱입니다.
현재는 Android·iOS용 공식 Flutter 기본 프로젝트이며, 화면은 기본 카운터 예제입니다.

## 개발 환경

- Flutter: 3.47.5 stable
- Dart: 3.13.4
- 앱 코드: `lib/main.dart`
- 기본 위젯 테스트: `test/widget_test.dart`

이번 초기화에 사용한 SDK는 `C:\Users\jack4\AppData\Local\Temp\codex-backpack-flutter`에 있습니다.
임시 폴더이므로 장기 개발 시 Flutter SDK를 영구 경로에 설치하고 해당 `bin` 폴더를 PATH에 추가하세요.

현재 PC에서는 프로젝트 루트의 PowerShell에서 다음처럼 실행할 수 있습니다.

```powershell
$env:Path = "$env:TEMP\codex-backpack-flutter\bin;$env:Path"
flutter pub get
flutter doctor
flutter devices
flutter run
```

`flutter run` 전에 Android 에뮬레이터를 켜거나 USB 디버깅을 허용한 Android 기기를 연결하세요.
현재 Android SDK는 설치되어 있으나 Command-line Tools가 누락되어 있습니다.
Android Studio의 SDK Manager → SDK Tools에서 Android SDK Command-line Tools를 설치하고,
`flutter doctor --android-licenses`를 실행해 라이선스를 검토·동의하세요.
iOS 빌드와 실행에는 macOS 및 Xcode가 필요합니다.

## 검증

```powershell
dart analyze
flutter test
```

초기 생성 후 Dart 정적 분석에서 문제가 없었으며 기본 위젯 테스트 1개가 통과했습니다.
현재 환경의 `flutter analyze`는 분석 서버의 JSON 파싱 오류로 종료되어 `dart analyze`로 검증했습니다.
Android APK 빌드와 실제 기기 실행은 아직 검증하지 않았습니다.

## 구현 방향

여행 생성·초대 코드 참여부터 시작하여 일정, 경비, OCR, 최종 정산 기능을 순서대로 추가합니다.
기능별 코드는 필요할 때 `lib/features/` 아래에 구성하고 공통 UI와 서버 통신 코드는 `lib/core/`로 분리합니다.
백엔드 API 연결과 외부 서비스 연동은 아직 구현되지 않았습니다.
