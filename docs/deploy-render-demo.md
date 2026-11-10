# Render 무료 임시 시연

브랜치: `codex/chore/render-demo`. 이 구성은 `main`에 병합하지 않고 별도로 사용한다.

## 무엇이 올라가나요?

- Free Docker Web Service: Spring Boot API + H2 메모리 DB
- Free Key Value: 로그인 제한·리프레시 토큰·캐시용 Redis 호환 저장소
- HTTPS 주소: Render가 배포 후 발급하는 `https://<서비스명>.onrender.com`
- JWT 키: Blueprint에서 자동 생성. 저장소에는 실제 키를 넣지 않는다.

회원가입·로그인·여행 생성 등 실제 API를 사용한다. 초기 DB는 비어 있고 개발용 더미 계정은 생성하지 않는다.
서버가 재시작·재배포·절전되면 가입한 계정, 여행, 지출과 업로드 이미지가 초기화된다. 다시 가입해야 한다.
Redis가 따로 살아 있어도 회원 DB는 비워지므로 기존 로그인 세션은 사용할 수 없다.
중요한 개인정보나 보존해야 하는 데이터는 넣지 않는다.

## Render에서 시작하기

1. Render Dashboard에서 **New → Blueprint**를 선택한다.
2. GitHub 저장소 `sasiljangnan2/Backpack_Crop`를 연결한다.
3. 브랜치를 **`codex/chore/render-demo`**, Blueprint 파일을 **`render.yaml`**로 선택한다.
4. `backpack-render-demo`와 `backpack-render-demo-redis`가 모두 **Free**인지 확인한 뒤 배포한다.
5. Web Service가 **Live**가 되면 서비스의 외부 HTTPS 주소를 복사한다.

이미 무료 Key Value를 쓰고 있는 Render 워크스페이스는 무료 인스턴스를 하나 더 만들 수 없다.
그 경우 기존 인스턴스의 용도를 먼저 확인하고, 덮어쓰거나 유료 플랜으로 바꾸지 않는다.
서비스 이름이 다른 기존 서비스와 겹치면 기존 리소스를 수정하지 않도록 Blueprint의 이름 및 `fromService.name`을 함께 바꾼다.

Render 설정 요약:

| 항목 | 값 |
| --- | --- |
| Branch | `codex/chore/render-demo` |
| Dockerfile | `backend/Dockerfile.render-demo` |
| Docker build context | `backend` |
| Root directory | 비워 둠 (저장소 루트) |
| Profile | `render-demo` 단독 |
| Health check | `/files/render-health.txt` |
| 자동 배포 | 꺼짐 — 필요할 때 수동 배포 |

`prod`/`dev`를 함께 켜거나 운영 DB 주소를 넣지 않는다. MySQL 마이그레이션은 이 프로필에서 실행하지 않는다.
H2 의존성은 `-PrenderDemo=true` 빌드에만 포함되며 기존 Dockerfile과 운영 MySQL 설정은 그대로 유지한다.

## 앱 연결

빌드할 때 실제 Render 주소를 지정한다 (아래 주소는 예시):

```powershell
flutter run --dart-define=API_BASE_URL=https://<실제-서비스명>.onrender.com
```

APK를 만들 경우:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://<실제-서비스명>.onrender.com
```

앱에 서버 주소를 따로 저장했다면 앱의 서버 주소 설정도 확인한다. 이전 서버 주소가 우선 적용될 수 있다.

## 확인할 것

1. `/files/render-health.txt`가 HTTP 200으로 응답하는지 확인한다.
2. 앱에서 이메일·영문과 숫자를 포함한 8~64자 비밀번호·이름으로 가입한다.
3. 로그아웃 후 같은 계정으로 로그인한다.
4. 여행을 만들고 다른 기기에서 초대 코드로 참여한다.

무료 서버는 유휴 15분 뒤 절전되며 다음 요청 때 다시 시작될 수 있다. 첫 접속은 약 1분 이상 걸릴 수 있으므로 브라우저에서 health 주소를 먼저 열고 응답을 받은 뒤 앱을 사용한다.
푸시 알림은 꺼져 있으며, 지도는 기본 OpenStreetMap, AI는 별도 키가 없으면 규칙 기반 추천을 쓴다.
H2 시연은 운영 MySQL의 Flyway 마이그레이션 검증을 대신하지 않는다.

## 로컬 검증

```powershell
cd backend
.\gradlew.bat test --tests '*RenderDemoAuthTest' bootJar -PrenderDemo=true --no-daemon
```

새 프로필의 DB 생성·회원가입·로그인·보호 API 인증을 검사한다. 이 테스트의 Redis는 메모리 대역이므로 실제 Render Redis 연결은 배포 후 별도로 확인한다.

공식 문서: [무료 서비스 제한](https://render.com/docs/free) · [Blueprint 설정](https://render.com/docs/blueprint-spec)
