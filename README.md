# Backpack

그룹 여행 일정과 공동 경비를 관리하기 위한 Flutter 모바일 앱입니다.
현재는 Android·iOS용 공식 Flutter 기본 프로젝트이며, 화면은 기본 카운터 예제입니다.

## 개발 환경

- Flutter: 3.47.5 stable
- Dart: 3.13.4
- 앱 코드: `lib/main.dart`
- 기본 위젯 테스트: `test/widget_test.dart`

Flutter SDK는 영구 경로인 `C:\Users\jack4\develop\flutter`에 설치되어 있습니다.
사용자 PATH에 SDK의 `bin` 폴더를 등록했습니다. 열려 있던 터미널과 IDE는 재시작하세요.

현재 PC에서는 프로젝트 루트의 PowerShell에서 다음처럼 실행할 수 있습니다.

```powershell
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
Android 디버그 APK 빌드, 에뮬레이터 설치 및 Flutter 실행을 확인했습니다. 실제 휴대폰 실행은 아직 검증하지 않았습니다.

## 구현 방향

여행 생성·초대 코드 참여부터 시작하여 일정, 경비, OCR, 최종 정산 기능을 순서대로 추가합니다.
기능별 코드는 필요할 때 `lib/features/` 아래에 구성하고 공통 UI와 서버 통신 코드는 `lib/core/`로 분리합니다.
백엔드 API 연결과 외부 서비스 연동은 아직 구현되지 않았습니다.

## Android Studio에서 열기

이 프로젝트의 개발 경로는 `C:\Users\jack4\develop\backpack`입니다.
Android Studio에서 이 폴더 전체를 열고 Android 에뮬레이터를 선택한 뒤 실행하세요.
원본 한글 경로의 프로젝트는 보존되어 있지만 두 폴더는 자동 동기화되지 않습니다.
앞으로는 이 영문 경로에서만 작업하세요.

한글 경로 검사만 해제해도 Android의 aapt 도구가 APK를 읽지 못할 수 있어 영문 경로를 사용합니다.
에뮬레이터 저장 공간이 부족하면 개발 기기에 맞는 APK를 빌드하세요.
현재 x64 에뮬레이터에서는 다음 명령으로 빌드 및 실행을 확인했습니다.

```powershell
flutter build apk --debug --target-platform android-x64
flutter run -d emulator-5554
```