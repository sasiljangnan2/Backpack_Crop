# Backpack

그룹 여행의 준비 · 일정 · 지출 · 정산을 함께 관리하는 Flutter 앱(Android · iOS)과 Spring Boot API 서버입니다.

- 앱: 이 폴더 (`lib/`). 모든 화면이 서버 API를 부릅니다
- 서버: [`backend/`](backend/README.md)
- 문서: [API 명세](docs/api/README.md) · [ERD](docs/erd/README.md) · [디자인 기준](docs/design-reference.md)

## 기능

| 영역 | 화면 |
| --- | --- |
| 회원 | 회원가입 · 로그인 (토큰 자동 재발급) · 내 정보 · 알림 설정 · 비밀번호 변경 · 탈퇴 |
| 여행 | 목록 · 만들기/수정 (여행지 프리셋, 통화 · 시간대) · 초대 코드 공유 · 코드로 참여 · 나가기 · 삭제 |
| 홈 | D-day / 여행 N일차, 현지 시각, 다음 일정 · 지연 안내, 공동 지출 · 내 정산 요약 |
| 일정 | 날짜별 일정, 추가 · 수정 · 고정, 예약 상태, 시간 겹침 안내, 활동 기록(실제 시작 · 종료, 지연 시간) |
| 장소 투표 | 만들기 · 투표 · 마감하면서 일정에 넣기 |
| 경비 | 지출 등록(현지 통화 · 원화, 그날 환율 · 선불 환율 · 직접 입력, 균등 · 항목별 · 개별 금액), 상세 · 수정 · 삭제 |
| 정산 | 사람별 잔액, 최소 송금 경로, 내 계산 근거, 결과 공유와 공유 기록 |
| 예산 | 분류별 예산과 실제 지출, 1인 준비 금액 (여행 통화 예산은 오늘 환율로 환산) |
| 준비 | 함께 할 업무(담당자 지정) · 내 준비물 체크리스트 |
| 알림 | 알림함 · 안 읽은 수 배지 · 누르면 해당 화면으로 이동, FCM 푸시 (설정했을 때) |

환율은 서버가 한국수출입은행(키가 있을 때) → 유럽중앙은행(Frankfurter) → ExchangeRate-API 순으로 받아 둡니다.

## 개발 환경

- Flutter 3.47 stable · Dart 3.13 (`pubspec.yaml`의 `sdk: ^3.13.0`)
- 백엔드: Java 21, MySQL 8, Redis 8 ([`backend/README.md`](backend/README.md))

Flutter SDK와 프로젝트는 한글 · 공백이 없는 경로에 두세요 (예: `C:\dev\flutter`, `C:\dev\backpack`). Android 설정은 아래 [Android Studio 설정 및 실행](#android-studio-설정-및-실행)을 참고하세요.

## 로컬에서 실행

1. 서버를 띄웁니다 (`backend` 폴더, 자세한 내용은 [`backend/README.md`](backend/README.md)).

   ```powershell
   copy .env.example .env
   docker compose up -d
   .\gradlew.bat bootRun
   ```

2. 앱을 실행합니다 (프로젝트 루트).

   ```powershell
   flutter pub get
   flutter run
   ```

   앱은 기본으로 Android 에뮬레이터에서 `http://10.0.2.2:8080`(PC의 localhost), 그 밖에서는 `http://localhost:8080`을 부릅니다.
   실제 휴대폰에서 PC 서버를 쓰려면 PC의 IP를 넣습니다 (디버그 빌드만 http를 허용합니다).

   ```powershell
   flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8080
   ```

dev 프로필 서버는 DB가 비어 있으면 더미 계정(`host@backpack.dev` / `backpack1234` 등)과 오사카 여행을 넣습니다. 새 계정으로 가입해서 써도 됩니다.

## 빌드 설정 (`--dart-define`)

| 이름 | 설명 |
| --- | --- |
| `API_BASE_URL` | 서버 주소. **출시 빌드는 반드시 `https://` 주소**를 넣습니다 (출시 빌드는 http를 막습니다) |
| `FIREBASE_API_KEY` · `FIREBASE_APP_ID` · `FIREBASE_MESSAGING_SENDER_ID` · `FIREBASE_PROJECT_ID` | 푸시 알림용 Firebase 값. 넷 다 있을 때만 푸시를 켭니다. 없으면 알림함만 씁니다 |

값이 많으면 파일로 넘길 수 있습니다: `flutter build appbundle --dart-define-from-file=release.json`

## 출시 빌드

1. **서버**: HTTPS로 서버를 배포합니다 (`backend/README.md`의 운영 환경변수 참고).
2. **서명 키** (처음 한 번):

   ```powershell
   keytool -genkey -v -keystore android\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

   `android/key.properties`를 만듭니다. 키와 이 파일은 저장소에 올리지 않습니다 (`.gitignore`에 있음).

   ```properties
   storeFile=../upload-keystore.jks
   storePassword=...
   keyAlias=upload
   keyPassword=...
   ```

   `key.properties`가 없으면 출시 빌드도 디버그 키로 서명됩니다 (스토어에 올릴 수 없음).
3. **푸시 (선택)**: Firebase 콘솔에서 프로젝트를 만들고 Android 앱(`com.backpackcorp.backpack`)과 iOS 앱(같은 번들 ID)을 추가합니다.
   앱에는 위 `FIREBASE_*` 값을 넣고, 서버에는 서비스 계정 키 파일을 `FIREBASE_CREDENTIALS_PATH`로 지정합니다.
   iOS는 Apple Developer에서 APNs 키를 만들어 Firebase에 올리고, Xcode에서 Push Notifications · Background Modes(Remote notifications)를 켭니다.
4. **빌드**:

   ```powershell
   flutter build appbundle --release --dart-define=API_BASE_URL=https://api.example.com   # Play 스토어 (.aab)
   flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com         # 직접 설치 (.apk)
   flutter build ipa --release --dart-define=API_BASE_URL=https://api.example.com         # iOS (macOS에서)
   ```

앱 아이콘은 `assets/icon/`에 있고 `tool/make_icon.py`로 다시 만들 수 있습니다. 바꾼 뒤 `dart run flutter_launcher_icons`를 실행합니다.

## 검증

```powershell
flutter analyze
flutter test
```

`test/`에는 화면 없이 도는 단위 테스트(형식 · API 클라이언트 토큰 재발급 · 오류 변환)와 로그인 화면 위젯 테스트가 있습니다.

## 폴더 구조

```
lib/
├── main.dart · app.dart     시작, 로그인 상태에 따라 첫 화면 선택, 푸시를 누르면 해당 화면으로 이동
├── core/
│   ├── config/              --dart-define 설정
│   ├── network/             ApiClient (토큰 · 재발급 · 오류), JSON 도우미
│   ├── push/                FCM 토큰 등록 · 수신
│   ├── theme/ · widgets/    색 · 테마 · 공통 위젯
│   └── utils/               금액 · 날짜 형식, 여행지 프리셋
└── features/<기능>/
    ├── data/                모델 · API 호출
    └── presentation/        화면
```

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
3. 시작 화면(로그인 · 회원가입)이 표시되면 초기 실행이 완료된 것입니다. 로그인하려면 서버가 떠 있어야 합니다.
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

`backend/` 폴더는 앱이 사용하는 REST API 서버입니다. 자세한 실행 방법과 개발 규칙은 [`backend/README.md`](backend/README.md)를 참고하세요.

인증 · 여행 · 일정 · 투표 · 준비 업무 · 지출 · 환율 · 예산 · 정산 · 알림 API가 모두 구현되어 있습니다. 회원가입 · 로그인 · 토큰 재발급과 이미지 파일을 빼면 모든 요청에 액세스 토큰이 필요합니다.

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
