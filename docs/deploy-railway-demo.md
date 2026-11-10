# Railway 임시 시연 배포

브랜치: `codex/chore/railway-demo`. `main`에는 합치지 않는 별도 배포 구성이다.

## 구성과 비용

- API: Spring Boot + H2 메모리 DB, Docker 빌드
- Redis: Railway Redis 서비스 (리프레시 토큰, 로그인 제한, 캐시)
- 회원·여행·지출·이미지는 API 서버 재시작·재배포 시 초기화된다. 개발용 더미 계정은 만들지 않으므로 회원가입부터 진행한다.
- Railway는 사용량을 크레딧에서 차감한다. 체험/무료 계정의 잔여 크레딧과 만료일을 확인하고 유료 플랜 전환이나 결제 등록은 별도로 결정한다.

## 서비스 설정

1. 빈 프로젝트를 만들고 Redis 서비스를 추가한다. 서비스 이름은 `Redis`로 둔다.
2. GitHub 저장소 `sasiljangnan2/Backpack_Crop`에서 **`codex/chore/railway-demo` 브랜치**를 연결해 API 서비스를 추가한다.
3. API 서비스의 Root Directory는 비워 둔다. 현재 Railway 신규 서비스는 기존 Config as Code를 사용할 수 없으므로 아래 항목을 대시보드 Settings에서 직접 설정한다.
4. Dockerfile은 `backend/Dockerfile.railway-demo`, build context는 저장소 루트다. 기존 운영용 Dockerfile을 선택하지 않는다.
5. Healthcheck Path는 `/files/demo-health.txt`, Healthcheck Timeout은 `300`, 재시도 횟수는 `2`, API 메모리 상한은 `0.5 GB`로 설정한다.
6. 아래 API 환경변수를 저장한 뒤 배포한다. JWT 키는 서비스별로 무작위 생성한 32바이트 이상 비밀 값이며 저장소나 문서에 기록하지 않는다.

| 이름 | 값 |
| --- | --- |
| `SPRING_PROFILES_ACTIVE` | `demo` |
| `RAILWAY_DOCKERFILE_PATH` | `backend/Dockerfile.railway-demo` |
| `REDIS_URL` | `${{Redis.REDIS_URL}}` (이름이 다르면 실제 Redis 서비스 이름으로 변경) |
| `JWT_SECRET` | 무작위 32바이트 이상 비밀 값 |
| `PUBLIC_BASE_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` |

Redis의 메모리 폐기 정책은 `noeviction`으로 설정한다. 별도 Redis 서비스에도 비밀번호 인증을 유지한다.
API의 포트는 Railway가 넣는 `PORT`를 그대로 사용하고 `0.0.0.0`으로 바인딩한다.
`prod` 또는 `dev` 프로필을 함께 활성화하지 않고 운영 MySQL 주소를 넣지 않는다.

7. API 서비스 Networking에서 **Generate Domain**으로 HTTPS 주소를 만든다.
8. `/files/demo-health.txt`의 HTTP 200 응답과 회원가입 → 로그아웃 → 재로그인을 확인한다.

## 앱 연결

```powershell
flutter run --dart-define=API_BASE_URL=https://<실제-도메인>.up.railway.app
```

APK를 만들려면:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://<실제-도메인>.up.railway.app
```

앱에 서버 주소를 따로 저장했다면 앱의 서버 주소 설정도 확인한다. 이전 주소가 빌드 기본값보다 우선 적용될 수 있다.
푸시는 꺼져 있고, AI 키가 없으면 규칙 기반 추천을 사용한다. 지도·환율 외부 통신은 계정의 네트워크 제한에 영향을 받는다.
H2 기반 시연은 운영 MySQL의 Flyway 검증을 대신하지 않는다.

## 검증

```powershell
cd backend
.\gradlew.bat test --tests '*DemoAuthTest' bootJar -Pdemo=true --no-daemon
```

시연 프로필의 DB 생성·가입·로그인·보호 API 인증을 검사한다. 테스트 Redis는 메모리 대역이며 실제 Railway Redis 연결은 배포 후 별도로 확인한다.
H2는 `-Pdemo=true` 빌드에만 포함된다. 기존 운영 Dockerfile과 MySQL 설정은 유지한다.

공식 문서: [Docker](https://docs.railway.com/builds/dockerfiles) · [설정 파일](https://docs.railway.com/config-as-code/reference) · [체험 크레딧](https://docs.railway.com/pricing/free-trial)

## 비용과 종료

포함 사용량은 기존 프로젝트와 공유된다. 시연 전후 Usage에서 총 사용량을 확인한다.
API는 JVM heap 256MB·컨테이너 0.5GB 상한, Redis는 데이터 메모리 64MB·`noeviction`으로 제한한다.
메모리 상한은 청구 금액 상한을 보장하지 않는다. 시연 후에는 새 프로젝트의 API와 Redis 배포를 모두 중지(Remove deployment)해 실행 비용을 멈춘다.
운영 중인 다른 프로젝트나 워크스페이스 전체 설정은 변경하지 않는다.

## 2026-11-10 배포 확인

- API: https://backpackcrop-production.up.railway.app
- 프로젝트: https://railway.com/project/3efb6f69-d22a-477d-a4ef-a8649b645e45
- 로컬: `DemoAuthTest` 통과 및 시연 JAR 빌드 성공
- 실제 HTTPS API: health 200, 가입 201, 로그인 200, 인증된 내 정보 200, 토큰 없는 요청 401, 토큰 재발급 200, 로그아웃 204 확인
- 실제 Railway Redis를 사용한 토큰 발급·재발급 확인
- 이 주소는 임시 시연용이며, 시연 종료 후 API와 Redis를 모두 중지해야 실행 비용이 멈춘다.
