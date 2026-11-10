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
3. API 서비스의 Root Directory는 비워 두고, 설정 파일은 저장소 루트의 `railway.json`을 사용한다.
4. Dockerfile은 `backend/Dockerfile.railway-demo`, build context는 저장소 루트다. 기존 운영용 Dockerfile을 선택하지 않는다.
5. 아래 API 환경변수를 저장한 뒤 배포한다. JWT 키는 서비스별로 무작위 생성한 32바이트 이상 비밀 값이며 저장소나 문서에 기록하지 않는다.

| 이름 | 값 |
| --- | --- |
| `SPRING_PROFILES_ACTIVE` | `demo` |
| `REDIS_URL` | `${{Redis.REDIS_URL}}` (이름이 다르면 실제 Redis 서비스 이름으로 변경) |
| `JWT_SECRET` | 무작위 32바이트 이상 비밀 값 |
| `PUBLIC_BASE_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` |

Redis의 메모리 폐기 정책은 `noeviction`으로 설정한다. 별도 Redis 서비스에도 비밀번호 인증을 유지한다.
API의 포트는 Railway가 넣는 `PORT`를 그대로 사용하고 `0.0.0.0`으로 바인딩한다.
`prod` 또는 `dev` 프로필을 함께 활성화하지 않고 운영 MySQL 주소를 넣지 않는다.

6. API 서비스 Networking에서 **Generate Domain**으로 HTTPS 주소를 만든다.
7. `/files/demo-health.txt`의 HTTP 200 응답과 회원가입 → 로그아웃 → 재로그인을 확인한다.

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
