# Backpack

그룹 여행 일정과 공동 경비를 관리하기 위한 Flutter 모바일 앱입니다.
회원가입·로그인, 여행 목록·생성·초대 코드 참여, 경비 등록·분담 미리보기를 제공합니다.
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

## 회원가입·로그인과 여행 화면

- 시작 화면의 **회원가입 → 로그인 → 내 여행 → 여행 만들기**로 진행합니다.
- **새 여행 화면 미리보기**에서는 서버 없이 여행 목록·생성·초대 코드·멤버를 확인할 수 있습니다. 미리보기의 참여 코드는 `DEMO2026`입니다.
- 실제 로그인은 회원가입 응답의 사용자 정보와 로그인 응답의 토큰 두 개를 별도로 처리합니다.
- 액세스·리프레시 토큰은 기기의 보안 저장소에 한 쌍으로 저장합니다. 재실행 때 재발급하여 세션을 복원합니다. 비밀번호는 저장하지 않습니다.
- 여행 상세에서 해당 여행의 멤버 ID를 사용하는 경비 미리보기로 이동할 수 있습니다. 여행별 미리보기 지출은 앱 종료 시 초기화됩니다.
- 코드는 서버 도메인에 맞춰 `lib/features/user/`, `lib/features/trip/`에 둡니다.

Android 에뮬레이터는 기본으로 개발 PC의 `http://10.0.2.2:8080`에 연결합니다.
다른 서버는 프로젝트 루트에서 아래처럼 지정합니다. 개발용 HTTP 예외는 에뮬레이터와 localhost에만 적용됩니다.

```powershell
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

실제 여행 기능에는 여행 목록·생성·상세·멤버·초대 코드 참여 API가 제공되는 서버가 필요합니다.
현재 `main`의 인증 API와 `feat/trip`의 여행 DTO 형식을 기준으로 요청·응답 계약 테스트를 구성했습니다.
여행 API가 아직 반영되지 않은 서버에서는 오류와 재시도를 표시합니다.
**미리보기는 로그인 성공이나 서버 저장으로 처리하지 않습니다.**

## 여행 일정 화면

**새 여행 화면 미리보기 → 여행 선택 → 여행 일정 보기**에서 확인합니다.
날짜별 일정 추가·수정·삭제, 고정·고정 해제, 예약 상태·메모를 지원합니다.
일정 추가는 현재 선택한 날짜를 사용하고, 다른 날짜로 수정하면 그 날짜로 목록이 이동합니다.
시작·종료 시간과 겹치는 일정을 확인하며, 삭제·입력 취소·동시 수정 충돌은 사용자 확인을 거칩니다.

미리보기 일정은 여행별로 분리해 앱 실행 중 유지합니다. 실제 여행은 기존 명세의 일정 API를 호출하며
오류가 나도 샘플 데이터로 자동 대체하지 않습니다. 실제 서버의 일정 API 구현이 필요합니다.
UI 기준과 근거는 [디자인 기준](docs/design-reference.md#일정-화면의-ux-기준)을 참고하세요.

## 프론트엔드 경비 화면

구조와 데이터 형식은 [Flutter 규칙](docs/convention/frontend/flutter.md)과
[API 명세의 지출 항목](docs/api/README.md#9-지출)을 따릅니다.

홈의 **경비 → 지출 추가 → 분담 정하기 → 이 분담으로 적용** 순서로 확인합니다.
지출명·날짜·카테고리·결제자·엔화/원화·여러 항목을 입력할 수 있고,
등록한 지출을 눌러 상세 내역을 보거나 수정할 수 있습니다.

- `lib/features/expense/data/`: 요청 DTO, 데이터 공급 인터페이스, 샘플 저장소
- `lib/features/expense/presentation/`: 목록·입력·분담·상세 화면, 상태 관리, 문구·위젯
- `ExpenseSplitController.createRequest()`: 기존 지출 추가 API 명세의 요청 바디

샘플 지출은 같은 앱 실행 중 탭을 바꾸어도 유지됩니다. 앱을 완전히 종료하면 초기화됩니다.
서버 API는 호출하지 않으며 원화 환산·분담액은 화면용 미리보기입니다.
엔화는 직접 입력한 환율의 `MANUAL` 모드, 원화는 `KRW` 모드를 사용합니다.
`EQUAL`은 총액 항목 하나, `ITEM`은 항목별 멤버 ID 목록을 준비합니다.
미리보기의 원화 환산·분담액을 서버 계산 결과로 확정하지 않습니다.
서버 연결 시 `ExpenseRepository`를 구현하고 저장 응답의 금액과 분담액을 표시해야 합니다.

## 백엔드 (Spring Boot)

`backend/` 폴더는 앱이 사용하는 REST API 서버입니다. 자세한 실행 방법과 개발 규칙은 [`backend/README.md`](backend/README.md)를 참고하세요.

현재 인증 API(회원가입·로그인·토큰 재발급·로그아웃)가 구현되어 있습니다. 여행 등 다른 도메인은 해당 API가 구현된 서버 브랜치를 사용해야 합니다.

### 기술 스택

| 항목 | 값 |
| --- | --- |
| Language | Java 21 |
| Framework | Spring Boot 4.1.1 (Gradle Kotlin DSL) |
| DB | MySQL 8.4, 스키마는 Flyway로 관리 (`src/main/resources/db/migration`) |
| Cache / 토큰 저장 | Redis 8 |
| 인증 | JWT (Spring Security OAuth2 Resource Server) |
| 푸시 알림 | Firebase Cloud Messaging (`firebase-admin`) |
| Package | `com.backpackcorp.backpack` |

### 빠른 실행

Java 21과 Docker가 필요합니다. `backend` 폴더에서 실행합니다.

```bash
cp .env.example .env    # 로컬 설정 (JWT_SECRET이 없으면 서버가 뜨지 않음)
docker compose up -d    # MySQL(3306), Redis(6379)
./gradlew bootRun       # http://localhost:8080
```

Windows PowerShell에서는 `copy .env.example .env`, `.\gradlew.bat bootRun`을 사용합니다.
처음 실행하면 Flyway가 테이블을 만들고, DB가 비어 있으면 더미 데이터(회원·여행·일정·지출 등)를 넣습니다.

### 테스트

```bash
./gradlew build
```

테스트는 H2와 메모리 캐시로 실행되므로 MySQL·Redis 없이 돌아갑니다.
PR에서는 GitHub Actions(`Backend CI`)가 빌드·테스트 후 실제 MySQL에 서버를 띄워 마이그레이션까지 확인합니다.

### 관련 문서

- [ERD](docs/erd/README.md) · [API 명세](docs/api/README.md)
- [백엔드 컨벤션](docs/convention/backend/spring.md) · [프론트·백엔드 공통 약속](docs/convention/common/code.md)
