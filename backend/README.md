# Backpack Backend

여행 준비·일정·지출·정산을 함께 관리하는 Backpack 앱(Flutter)의 API 서버.

Spring Boot 4 · Java 21 · MySQL 8.4 · Redis 8 · Flyway

## 로컬 실행

Java 21과 Docker가 필요하다. (Docker 없이 PC에 설치한 MySQL 8 · Redis를 써도 된다. `.env`의 접속 정보만 맞추면 된다.)

```bash
cp .env.example .env        # 로컬 설정. JWT_SECRET이 없으면 서버가 뜨지 않는다
docker compose up -d        # MySQL(3306), Redis(6379)
./gradlew bootRun           # http://localhost:8080
```

테이블은 서버가 뜰 때 Flyway가 `src/main/resources/db/migration`의 SQL로 만든다.

DB에 회원이 없으면 더미 데이터(회원 3명, 오사카 여행 1개와 그 일정·투표·지출·정산)가 함께 들어간다.
계정과 비밀번호는 `DummyDataInitializer`에 있다. 다시 넣으려면 `docker compose down -v`로 DB를 비우고 다시 띄운다.

## 테스트

```bash
./gradlew build
```

테스트는 H2와 메모리 캐시로 돌아가므로 MySQL·Redis 없이 실행된다.
마이그레이션 SQL과 엔티티가 맞는지는 CI가 실제 MySQL에 서버를 띄워 확인한다 (`scripts/smoke-boot.sh`).

## 폴더 구조

```
src/main/java/com/backpackcorp/backpack
├── global        공통: 설정(config), 예외·에러 응답(exception), 토큰(security), 이미지 저장(storage), 공통 DTO·엔티티
├── user          회원
├── trip          여행, 멤버
├── task          준비 업무
├── schedule      일정
├── poll          투표
├── budget        예산, 환율
├── expense       지출
├── settlement    정산
└── notification  알림, 기기 토큰
```

도메인 폴더는 `controller / service / repository / domain / dto`로 나눈다.

## 개발할 때 알아 둘 것

- **DB 변경**: `V1__init.sql`은 고치지 않는다. `V2__설명.sql`처럼 새 파일을 추가한다.
- **에러 응답**: `throw new BaseException(ErrorCode.XXX)`. 코드는 `ErrorCode`에 추가한다. 응답 형식은 `ErrorResponse` 하나다.
- **로그인한 사용자**: 컨트롤러에서 `@AuthenticationPrincipal BackpackUserDetails user`로 받는다.
- **여행 멤버 확인**: `tripMemberGuard.requireMember(tripId, user.getId())`. 멤버가 아니면 403이다.
- **목록 응답**: `SliceCursorPageResponse` (커서 방식, 무한 스크롤용).
- **이미지**: `ImageStorage.store()`가 돌려준 키를 DB에 저장하고, 응답에는 `url(key)`를 내려준다. 로컬에서는 `storage/`에 쌓인다.
- **시각**: `Instant`(UTC)로 저장하고 ISO-8601 문자열로 응답한다. 일정의 날짜·시각은 여행지 현지 기준(`trips.time_zone`)이다.
- **지금 시각**: `LocalDate.now()` 대신 `Clock` 빈을 주입받는다. 시연 때는 `APP_DEMO_NOW=2026-10-03T05:50:00Z`로 고정할 수 있다.
- **인증**: `/api/auth/signup · login · reissue`와 `/files/**`만 토큰 없이 열려 있다. 나머지는 모두 `Authorization: Bearer {액세스 토큰}`이 필요하다.
- **금액 계산**: 원화 환산·끝전·송금 경로는 `ExpenseSplitCalculator`, `SettlementCalculator`(순수 함수)에 있다. 규칙을 바꾸면 그 테스트부터 고친다.
- **알림**: 서비스에서 `TripNotificationEvent`를 발행하면 `NotificationService`가 같은 트랜잭션에서 알림함에 저장하고, 커밋 뒤 `PushSender`가 따로(비동기) FCM을 보낸다. 받는 사람의 알림 설정 · 본인 제외는 `NotificationService`가 처리한다.
- **환율**: `ExchangeRateService`가 DB에 없으면 `ExchangeRateCollector`로 외부 API(`budget/service/rate`의 `ExchangeRateProvider` 구현들, `@Order` 순서)를 부른다. 2시간마다 `ExchangeRateScheduler`가 쓰는 통화의 오늘 환율을 미리 받는다. 테스트는 `exchange-rate.fetch-enabled: false`로 외부를 부르지 않는다.

## 로컬에서 API 직접 호출해 보기

```bash
# 더미 계정으로 로그인 → accessToken 복사
curl -s -X POST localhost:8080/api/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"host@backpack.dev","password":"backpack1234"}'

# 내 여행 목록
curl -s localhost:8080/api/trips -H "Authorization: Bearer {accessToken}"
```

## 운영 환경변수

`prod` 프로필(도커 이미지 기본값)은 아래 값이 없으면 뜨지 않는다.

| 변수 | 설명 |
|---|---|
| `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` | MySQL 접속 정보 |
| `REDIS_HOST` | Redis 주소. `REDIS_PORT`(기본 6379), `REDIS_PASSWORD`, `REDIS_SSL`(기본 false)은 선택 |
| `JWT_SECRET` | 32바이트 이상. `openssl rand -base64 48`로 만든다 |
| `STORAGE_PUBLIC_BASE_URL` | 이미지 주소의 앞부분. 예: `https://api.example.com/files` |
| `FIREBASE_CREDENTIALS_PATH` | FCM 서비스 계정 키 파일 경로. 푸시를 끄려면 빈 값으로 둔다 |

선택

| 변수 | 설명 |
|---|---|
| `EXIM_API_KEY` | 한국수출입은행 현재환율 API 인증키 (수출입은행 Open API에서 신청). 없으면 Frankfurter(ECB) → ExchangeRate-API만 쓴다 |
| `EXCHANGE_RATE_FETCH_ENABLED` | 기본 `true`. `false`면 외부 환율 API를 부르지 않고 DB에 쌓인 값만 쓴다 |
| `APP_DEMO_NOW` | 시연용 고정 시각. **운영에서는 설정하지 않는다.** |

운영 서버는 HTTPS 뒤(로드밸런서 · 리버스 프록시)에 둔다. 출시 앱은 http 서버에 접속하지 않는다.

이미지는 컨테이너의 `/app/storage`에 쌓이므로 볼륨을 붙여 실행한다.

```bash
docker build -t backpack-backend .
docker run -p 8080:8080 -v backpack-storage:/app/storage --env-file prod.env backpack-backend
```
