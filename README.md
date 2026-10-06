# Backpack

그룹 여행 일정과 공동 경비를 관리하기 위한 Flutter 모바일 앱입니다.
현재는 Android·iOS용 공식 Flutter 기본 프로젝트이며, 화면은 기본 카운터 예제입니다.
백엔드는 `backend/` 폴더의 Spring Boot 프로젝트입니다. 자세한 내용은 [백엔드](#백엔드-spring-boot) 절을 참고하세요.

## 개발 환경

- Flutter: 3.47.5 stable
- Dart: 3.13.4
- 앱 코드: `lib/main.dart`
- 기본 위젯 테스트: `test/widget_test.dart`

Flutter SDK를 영문 경로에 설치하세요. 아래의 `C:\dev\flutter`와 `C:\dev\backpack`은 예시이며, 자신의 설치 위치에 맞게 변경하세요.
사용자 PATH에 SDK의 `bin` 폴더를 등록하세요. 열려 있던 터미널과 IDE는 재시작하세요.

프로젝트 루트의 PowerShell에서 다음처럼 실행할 수 있습니다.

```powershell
flutter pub get
flutter doctor
flutter devices
flutter run
```

`flutter run` 전에 Android 에뮬레이터를 켜거나 USB 디버깅을 허용한 Android 기기를 연결하세요.
Android SDK 구성 요소는 아래 Android Studio 설정 절차에 따라 확인하세요.
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

## Android Studio 설정 및 실행

아래는 Windows 기준입니다. Android Studio 버전에 따라 메뉴 이름이나 위치가 조금 다를 수 있습니다.

### 1. Android Studio와 Flutter 플러그인 설치

1. [Android Studio](https://developer.android.com/studio)를 설치합니다. 이미 설치되어 있으면 실행합니다.
2. `File → Settings → Plugins → Marketplace`에서 `Flutter`를 검색해 설치합니다.
3. Dart 플러그인 설치 안내가 나오면 함께 설치하고 Android Studio를 재시작합니다.

### 2. 프로젝트 열기

1. 시작 화면의 `Open` 또는 `File → Open`을 선택합니다.
2. `C:\dev\backpack` 폴더를 엽니다.
3. 프로젝트 목록에서 `pubspec.yaml`, `lib`, `android`, `ios`가 보이는지 확인합니다.

`android` 하위 폴더만 열면 Flutter 앱 전체의 실행 설정을 사용하기 어렵습니다. `pubspec.yaml`이 있는 루트 폴더를 여세요.
팀원은 자신의 PC에서도 한글이나 공백이 없는 경로에 프로젝트를 받아 사용하세요.

### 3. Flutter SDK 경로 지정

`File → Settings → Languages & Frameworks → Flutter`에서 `Flutter SDK path`를 설정합니다.

```text
C:\dev\flutter
```

SDK 경로에는 `bin`을 붙이지 않습니다. 다른 PC에서는 해당 PC에 설치한 Flutter SDK 폴더를 선택하세요.
Dart SDK를 별도로 지정해야 한다면 다음 경로를 사용합니다.

```text
C:\dev\flutter\bin\cache\dart-sdk
```

사용자 PATH에 Flutter SDK의 `bin` 폴더(예: `C:\dev\flutter\bin`)를 추가하세요.
터미널에서 `flutter`를 찾지 못하면 Android Studio와 터미널을 완전히 종료한 뒤 다시 실행하세요.

### 4. Android SDK 확인

1. `Tools → SDK Manager`를 엽니다. 시작 화면에서는 `More Actions → SDK Manager`를 사용할 수 있습니다.
2. `SDK Platforms`에서 프로젝트에 필요한 플랫폼을 설치합니다. 이 프로젝트의 빌드에는 Android SDK Platform 36이 사용됐습니다.
3. `SDK Tools`에서 다음 항목을 확인하고 누락된 항목을 설치합니다.

   - Android SDK Build-Tools
   - Android SDK Platform-Tools
   - Android SDK Command-line Tools (latest)
   - Android Emulator

Android SDK의 실제 설치 위치는 SDK Manager의 `Android SDK Location`에서 확인하세요.
NDK 등 추가 구성 요소는 최초 빌드에서 다운로드될 수 있습니다.

프로젝트 루트의 Android Studio `Terminal`에서 다음 명령을 실행합니다.

```powershell
flutter doctor --android-licenses
flutter doctor
flutter pub get
```

라이선스를 읽고 동의한 뒤 `flutter doctor`의 Android toolchain 관련 오류를 해결하세요.

### 5. 에뮬레이터 생성 및 실행

1. `Tools → Device Manager`를 엽니다.
2. `+ → Create Virtual Device` 또는 `Create Device`를 선택합니다.
3. 휴대폰 모델을 고르고 PC에 맞는 Android 시스템 이미지를 다운로드합니다.
4. 생성이 끝나면 기기 옆의 실행 버튼을 누르고 Android 홈 화면이 뜰 때까지 기다립니다.

이미 만든 에뮬레이터가 있으면 새로 생성하지 않고 사용할 수 있습니다.
실제 Android 휴대폰을 사용할 때는 개발자 옵션의 USB 디버깅을 켜고, USB 연결 후 휴대폰에서 디버깅 연결을 허용하세요.

### 6. 앱 실행 및 코드 반영

1. 상단 실행 기기 목록에서 켜진 Android 에뮬레이터 또는 연결한 휴대폰을 선택합니다.
2. `lib/main.dart`를 열고 `Run`을 실행합니다. 실행 구성이 없다면 파일을 우클릭해 `Run 'main.dart'`를 선택하세요.
3. 기본 카운터 화면이 표시되면 초기 실행이 완료된 것입니다.
4. Dart 화면 코드를 수정한 뒤 `Hot Reload`로 변경을 반영합니다. 초기화 코드 변경 등은 `Hot Restart`, 네이티브 설정 변경은 앱을 중지하고 다시 실행해야 할 수 있습니다.

실행 대상에 Windows를 선택하면 `No Windows desktop project configured` 오류가 납니다. 이 프로젝트는 Android·iOS용으로 생성했습니다.
iOS 빌드와 실행에는 macOS 및 Xcode가 필요합니다.

터미널에서도 실행할 수 있습니다. `<device-id>`는 `flutter devices`에 표시된 기기 ID로 바꾸세요.

```powershell
flutter devices
flutter run -d <device-id>
```

### 실행 오류 해결

| 증상 | 확인할 내용 |
| --- | --- |
| `No Windows desktop project configured` | 실행 대상을 Android 에뮬레이터로 변경합니다. |
| `non-ASCII characters`, `Illegal byte sequence`, APK의 manifest를 읽지 못함 | Android Studio에서 한글이 없는 프로젝트 경로(예: `C:\dev\backpack`)를 열었는지 확인합니다. 경로 검사만 해제해도 `aapt`의 한글 경로 오류는 남을 수 있습니다. |
| 기기가 목록에 없음 | Device Manager에서 에뮬레이터를 실행하고 `flutter devices`로 확인합니다. |
| `INSTALL_FAILED_INSUFFICIENT_STORAGE` | 에뮬레이터의 여유 공간을 확인합니다. x64 에뮬레이터라면 아래 명령으로 해당 아키텍처용 APK를 빌드할 수 있습니다. 계속 부족하면 불필요한 앱을 정리하거나 저장 공간이 충분한 새 에뮬레이터를 만드세요. `Wipe Data`는 해당 가상 기기의 데이터를 전부 삭제하므로 주의하세요. |
| SDK 변경 후 패키지 파일을 찾지 못함 | 실행을 중지하고 아래 Gradle 재시작 및 의존성 갱신 명령을 사용합니다. |

x64 에뮬레이터용 APK 빌드 예시:

```powershell
flutter build apk --debug --target-platform android-x64
```

SDK 변경 후 Gradle 및 패키지 갱신:

```powershell
.\android\gradlew.bat --stop
flutter pub get
flutter run
```

공식 안내: [Flutter의 Android Studio 설정](https://docs.flutter.dev/tools/android-studio), [Android 개발 환경 설정](https://docs.flutter.dev/platform-integration/android/setup)

## 백엔드 (Spring Boot)

`backend/` 폴더는 Spring Initializr로 생성한 REST API 서버입니다. 현재는 생성 직후 상태이며 API는 아직 구현되지 않았습니다.

### 프로젝트 설정

| 항목 | 값 |
| --- | --- |
| Build | Gradle - Kotlin (`build.gradle.kts`) |
| Language | Java 21 |
| Spring Boot | 4.1.1 |
| Packaging | Jar |
| Configuration | YAML (`src/main/resources/application.yaml`) |
| Group / Artifact | `com.backpackcorp` / `backend` |
| Package | `com.backpackcorp.backpack` |

### 의존성

| 의존성 | 용도 |
| --- | --- |
| Spring Web | REST API (Spring MVC, Tomcat) |
| Validation | 입력값 검증 |
| Lombok | 반복 코드 자동 생성 |
| Spring Boot DevTools | 개발 중 자동 재시작 |
| Spring Data JPA | DB 접근 (Hibernate) |
| Flyway Migration | DB 스키마 버전 관리 (`flyway-mysql` 포함) |
| MySQL Driver | MySQL 접속 |

### 개발 환경

- JDK 21이 필요합니다. `java -version`으로 확인하세요.
- Gradle은 별도로 설치하지 않아도 됩니다. Gradle Wrapper(`gradlew.bat`)가 처음 실행할 때 자동으로 내려받습니다.
- IntelliJ IDEA에서는 `backend` 폴더를 열면 Gradle 프로젝트로 인식합니다. Lombok을 쓰려면 `Settings → Build, Execution, Deployment → Compiler → Annotation Processors`에서 `Enable annotation processing`을 켜세요.

### 빌드 및 실행

`backend` 폴더의 PowerShell에서 실행합니다.

```powershell
.\gradlew.bat compileJava   # 컴파일 확인
.\gradlew.bat bootRun       # 서버 실행 (기본 포트 8080)
.\gradlew.bat test          # 테스트
```

`application.yaml`에 DB 접속 정보(`spring.datasource`)가 아직 없습니다. 그래서 지금은 `bootRun`과 `test`가 DataSource 오류로 실패합니다.
MySQL 접속 정보를 설정한 뒤에 실행하세요. 비밀번호 같은 민감한 값은 커밋하지 말고 환경변수로 넘기세요.

### 검증

생성 직후 JDK 21 환경에서 `compileJava`와 `compileTestJava`가 성공했습니다. DB를 설정하지 않아 서버 실행과 테스트는 아직 확인하지 않았습니다.
