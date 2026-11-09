# 구글 지도 쓰기 (Google Maps Platform)

앱의 지도 · 장소 검색 · 이동 시간을 구글로 바꾼다. 키가 없으면 지금처럼 OpenStreetMap으로 돌아간다 (무료 · 키 없음).

| 쓰는 곳 | 구글 API | 키 | 월 무료 사용량 (2026-10 확인) |
|---|---|---|---|
| 앱 지도 (일정 지도 · 미리보기) | **Maps SDK for Android** | 안드로이드 키 | 휴대폰 앱 지도는 무제한 무료 |
| 장소 검색 · 지금 있는 곳 이름 | **Places API (New)** (Text Search · Nearby Search) | 서버 키 | 각 5,000건, 넘으면 1,000건에 약 $32 |
| 도보 · 대중교통 시간 | **Routes API** (Compute Route Matrix) | 서버 키 | 10,000칸(출발 × 도착), 넘으면 1,000칸에 약 $5 |

> **결제 계정(카드 등록)이 있어야 키가 동작한다.** 무료 사용량 안에서는 청구되지 않지만, 넘으면 청구된다.
> 아래 5번처럼 하루 한도와 예산 알림을 꼭 걸어 둔다. 요금은 [가격표](https://developers.google.com/maps/billing-and-pricing/pricing)에서 다시 확인한다.
> 서버는 같은 검색 · 경로 결과를 7일 동안 저장해 다시 묻지 않는다.

## 1. 프로젝트 · 결제

1. <https://console.cloud.google.com> → 새 프로젝트 (예: `backpack`)
2. **결제(Billing)** → 결제 계정 연결 (카드 등록)

## 2. API 켜기

**API 및 서비스 → 라이브러리**에서 세 개를 **사용**:

- Maps SDK for Android
- Places API (New) — 이름에 (New)가 붙은 것
- Routes API

## 3. 키 두 개 만들기

**API 및 서비스 → 사용자 인증 정보 → 사용자 인증 정보 만들기 → API 키**. 만든 키마다 **키 제한**을 건다.

**① 안드로이드 키** (앱 안에 들어간다)

- 애플리케이션 제한: **Android 앱** → 항목 추가
  - 패키지 이름: `com.backpackcorp.backpack`
  - SHA-1 (APK에 서명한 키의 지문. PC마다 다르다): `android` 폴더에서 `.\gradlew signingReport`를 실행하면 나온다
    - 시험용 APK (profile · debug): `Variant: debug`의 `SHA1`
    - 배포용 APK (release, `android\upload-keystore.jks`): `Variant: release`의 `SHA1` (`android\key.properties`가 있어야 배포용 키로 나온다)
    - 둘 다 넣어야 시험용 · 배포용 앱 모두에서 지도가 나온다
- API 제한: **Maps SDK for Android**만

**② 서버 키** (서버의 `.env`에만 둔다)

- API 제한: **Places API (New)**, **Routes API**
- 애플리케이션 제한: 클라우드에 올린 뒤 **IP 주소**에 서버 공인 IP를 넣는다 (PC에서 시험할 때는 비워 둔다)

## 4. 키 넣기

| 어디 | 방법 |
|---|---|
| PC 서버 | `backend\.env`에 `GOOGLE_MAPS_API_KEY=서버 키` → 서버를 껐다 켠다 |
| 클라우드 서버 | 서버 `~/backpack/.env`의 `GOOGLE_MAPS_API_KEY=`에 서버 키 → `docker compose up -d` |
| 시험용 APK | `flutter build apk --profile --target-platform android-arm64 --dart-define=API_BASE_URL=http://<PC IP>:8080 --dart-define=GOOGLE_MAPS_API_KEY=안드로이드 키` |
| 배포용 APK | `tool\build-release-apk.ps1 -ApiBaseUrl https://도메인 -GoogleMapsKey 안드로이드 키` |

키는 저장소 · zip에 넣지 않는다 (`.env`는 git에서 빠져 있고, 안드로이드 키는 빌드할 때만 준다).

## 5. 요금 안전장치

- **API 및 서비스 → 할당량**: Places API (New) · Routes API의 분당 · 하루 요청 수를 작게 줄인다 (하루 150건이면 월 무료 범위 5,000건 안이다)
- **결제 → 예산 및 알림**: 예산 1,000원 · 알림 50% · 90% · 100%

## 확인

- 앱의 일정 지도가 구글 지도로 보이고(왼쪽 아래 Google 로고), 장소 검색 아래에 "장소 검색: Google"이 보이면 된다
- 걸어서 20분이 넘는 구간은 "대중교통 N분"으로 바뀐다 (대중교통 경로가 없는 곳은 "차로 약 N분")
- 키가 틀리면 지도가 회색으로 비고, 서버 로그에 `구글 장소 검색 실패`가 남는다. 이때 서버는 OpenStreetMap으로 대신 찾는다
