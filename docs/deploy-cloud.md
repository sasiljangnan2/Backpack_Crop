# 클라우드 배포 (네이버 클라우드 Micro 서버)

PC를 꺼도 앱이 돌아가게, 서버를 **네이버 클라우드 플랫폼(NCP)** 서버 한 대에 올린다.
서버 · MySQL · Redis · HTTPS(Caddy)가 이 서버 하나에서 함께 돈다. 주소는 무료 도메인 **DuckDNS**를 쓴다.

```
휴대폰 앱 ──https──▶ backpack-xxxx.duckdns.org (서버 공인 IP)
                        └ Caddy(HTTPS 인증서 자동) → 서버(Spring Boot) → MySQL · Redis
```

| 항목 | 비용 |
|---|---|
| NCP **Micro 서버** (1 vCPU · 메모리 1GB · 디스크 10GB) | **1년 무료** (결제 정보를 등록한 달부터, 한국 거주자 1인 1대). 1년 뒤 반납하지 않으면 자동으로 유료 |
| 공인 IP | **유료** (Micro 무료에 들지 않는다. 요금은 콘솔의 요금 계산기에서 확인) |
| 신규 가입 크레딧 | 10만 원 · 3개월 (결제 수단 등록 후 신청). 공인 IP 요금 등에 쓸 수 있다 |
| DuckDNS 도메인 · HTTPS 인증서(Let's Encrypt) | 0원 |

> 무료 기간 · 크레딧 조건은 바뀔 수 있으니 가입할 때 [NCP 크레딧 이벤트](https://www.ncloud.com/main/creditEvent?tab=1)에서 다시 확인한다.
> 메모리 1GB는 빠듯하다. 설치 스크립트가 스왑(디스크 10GB면 1GB)을 만들고 서버 · MySQL 메모리를 줄여서 띄운다 (가족 · 친구 몇 명이 쓰기에는 충분하다).

## 1. 네이버 클라우드 가입 (직접)

1. <https://www.ncloud.com> → 회원가입 → 본인 인증
2. **결제 수단 등록** (Micro 1년 무료와 크레딧은 결제 수단을 등록해야 받을 수 있다)
3. [크레딧 이벤트](https://www.ncloud.com/main/creditEvent?tab=1)에서 신규 가입 크레딧 신청

## 2. 서버 만들기

콘솔 → **Services** → **Compute** → **Server** → **[서버 생성]** (신규 콘솔 화면)

| 단계 | 고를 것 |
|---|---|
| 서버 이미지 | **Ubuntu** (22.04 또는 24.04 중 최신) |
| VPC · Subnet | 없으면 [VPC 생성] · [Subnet 생성]. Subnet은 **Public** |
| 서버 타입 | **Micro** (목록에 있으면). 없으면 가장 작은 Standard (유료) |
| 공인 IP | **공인 IP 할당**을 켠다 (유료) |
| 스토리지 | 기본 10GB 그대로 (늘리면 유료) |
| 인증키 | **새로운 인증키 생성** → 이름 입력 → **[인증키 생성 및 저장]** → `.pem` 파일을 안전한 곳에 둔다 (관리자 비밀번호를 볼 때만 쓴다) |
| ACG | 기본(default-acg)을 고르고 3번에서 규칙을 고친다 |

**[서버 생성]** → 몇 분 뒤 서버 목록에 **운영중**이 되면 **공인 IP**를 적어 둔다 (예: `223.130.x.x`).

## 3. 포트 열기 (ACG)

콘솔 → **Server** → **ACG** → 서버에 붙은 ACG 선택 → **[ACG 설정]** → Inbound 규칙 추가

| 프로토콜 | 접근 소스 | 허용 포트 | 용도 |
|---|---|---|---|
| TCP | `내 IP` (또는 `0.0.0.0/0`) | `22` | PC에서 서버에 들어가기 (SSH) |
| TCP | `0.0.0.0/0` | `80` | HTTPS 인증서 받기 · http → https 넘기기 |
| TCP | `0.0.0.0/0` | `443` | 앱 접속 (HTTPS) |

**[적용]**. (Network ACL을 따로 만들었다면 거기에도 같은 포트를 연다. 기본값이면 손대지 않아도 된다.)

## 4. 관리자(root) 비밀번호 확인

서버 목록에서 서버 선택 → **[서버 관리 및 설정 변경]** → **관리자 비밀번호 확인** → 2번의 `.pem` 파일을 넣는다 → 비밀번호가 나온다.
계정은 `root`. 이 비밀번호로 PC에서 들어간다 (5번에서 두 번 묻는다).

## 5. 무료 도메인 (DuckDNS)

1. <https://www.duckdns.org> → GitHub · Google 계정 등으로 로그인
2. sub domain에 쓸 이름을 넣고(아래에서는 `<이름>`, 예: `backpack-myteam`) **add domain**
3. 그 줄의 **current ip**에 서버 공인 IP를 넣고 **update ip**

PC에서 `nslookup <이름>.duckdns.org`를 실행해 서버 IP가 나오면 된다.

## 6. 서버 올리기 (PC에서 한 줄)

```powershell
# 저장소(Backpack) 폴더의 backend 폴더에서
powershell -ExecutionPolicy Bypass -File scripts\deploy-cloud.ps1 -Server <서버 공인 IP> -Domain <이름>.duckdns.org
```

- 처음 접속하면 `Are you sure you want to continue connecting` 없이 바로 넘어가고, **root 비밀번호를 두 번** 묻는다 (복사 · 실행)
- 스크립트가 하는 일 (`backend/scripts/deploy-cloud.ps1` → 서버에서 `backend/deploy/setup-server.sh`):
  1. PC에서 서버 jar를 빌드해 `backend/deploy` 폴더와 함께 서버에 복사
  2. 서버에 Docker 설치, 디스크 정리(지난 이미지 · 캐시 · 오래된 로그), (메모리 1GB면) 스왑 · 메모리 절약 설정
  3. DB · Redis 비밀번호와 JWT 키를 무작위로 만들어 서버의 `~/backpack/.env`에 저장 (처음 한 번만)
  4. MySQL · Redis · 서버 · Caddy 시작, Let's Encrypt 인증서 발급, 매일 새벽 4시 DB 백업 예약
  5. `https://도메인`으로 서버가 응답하는지 확인

처음에는 10분쯤 걸린다 (서버 파일 약 130MB를 올리고 서버가 이미지 약 300MB를 받는다. PC는 휴대폰 핫스팟보다 일반 Wi-Fi에 둔다).
마지막에 **`준비됐어요: https://<이름>.duckdns.org`**가 나오면 끝이다.
브라우저로 `https://<이름>.duckdns.org/api/trips`를 열어 자물쇠 표시와 함께 `UNAUTHORIZED` 오류 JSON이 보이면 정상이다 (로그인하지 않아서 거절한 것).

> 비밀번호를 매번 넣기 싫으면 SSH 키를 한 번 등록한다:
> `ssh-keygen -t ed25519 -f $HOME\.ssh\backpack-ncp` → `type $HOME\.ssh\backpack-ncp.pub | ssh root@<IP> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"`
> 그다음부터 `-Key $HOME\.ssh\backpack-ncp`를 붙이면 묻지 않는다.

## 7. 서버에 키 넣기 (선택)

PC의 `backend\.env`에 있는 `GEMINI_API_KEY` · `GOOGLE_MAPS_API_KEY` · `EXIM_API_KEY`는 6번을 실행할 때 서버로 **자동으로** 넘어간다.
나중에 서버에서만 바꾸려면 서버에 들어가서 (`ssh root@<IP>` → `cd ~/backpack` → `nano .env`) 값을 채우고 `docker compose up -d`:

| 값 | 용도 |
|---|---|
| `GEMINI_API_KEY=` | AI 일정 재구성 (없으면 기본 추천) |
| `GOOGLE_MAPS_API_KEY=` | 구글 장소 검색 · 도보 · 대중교통 시간 (없으면 OpenStreetMap). [google-maps.md](google-maps.md) |
| `EXIM_API_KEY=` | 한국수출입은행 환율 (없으면 ECB · ExchangeRate-API) |

## 8. 앱 만들어 나눠 주기

```powershell
# 저장소(Backpack) 폴더에서
powershell -ExecutionPolicy Bypass -File tool\build-release-apk.ps1 -ApiBaseUrl https://<이름>.duckdns.org -GoogleMapsKey <구글 안드로이드 키>
```

- `-GoogleMapsKey`를 빼면 지도가 OpenStreetMap으로 나온다
- 결과: `Backpack_배포용.apk`. 카카오톡 · 구글 드라이브로 보내면 받는 사람이 설치할 수 있다 (설치할 때 "출처를 알 수 없는 앱 허용")
- 처음 실행하면 서명 키(`android\upload-keystore.jks` + `android\key.properties`)를 만든다. **두 파일을 USB · 클라우드 드라이브에 따로 백업한다.**
  잃어버리면 이미 설치한 사람이 업데이트를 받을 수 없다 (지우고 새로 설치해야 함). 저장소에는 올리지 않는다
- 전에 깐 시험용 앱(PC 서버용)은 서명이 달라 그 위에 덮어 설치되지 않는다. **시험용 앱을 지우고** 설치한다
- 클라우드 DB는 빈 상태로 시작한다. 모두 새로 회원가입한다

## 9. 업데이트

| 바꾼 것 | 다시 할 것 |
|---|---|
| 서버 (`backend/`) | 6번을 `-Domain` 없이: `scripts\deploy-cloud.ps1 -Server <IP>` (데이터 · `.env`는 그대로 남는다) |
| 앱 (`lib/`) | 8번을 다시 하고 새 APK를 나눠 준다 (서명 키가 같아 덮어 설치된다) |

## 10. 운영 메모

서버에 들어가기 (PowerShell): `ssh root@<서버 공인 IP>`. 서버 안에서 `cd ~/backpack` 후:

| 하고 싶은 것 | 명령 |
|---|---|
| 상태 보기 | `docker compose ps` |
| 서버 로그 보기 | `docker compose logs -f --tail 100 backend` (빠져나오기 Ctrl+C) |
| 다시 시작 | `docker compose restart backend` |
| 지금 백업 | `bash backup.sh` → `/var/backups/backpack/` (매일 자동, 14일 치 보관) |
| 설정 바꾸기 | `nano .env` 고친 뒤 `docker compose up -d` |
| 디스크 · 메모리 보기 | `df -h /` · `free -m` |

- **백업을 PC로 받기**: 백업은 서버 디스크에 있어 서버를 반납하면 함께 사라진다. 가끔 PC로 받아 둔다.
  `scp "root@<IP>:/var/backups/backpack/*" .`
- **1년 무료가 끝날 때**: 계속 쓸 게 아니면 콘솔에서 서버와 공인 IP를 **반납**한다 (반납하지 않으면 자동 유료). 반납하기 전에 백업을 받는다
- **푸시 알림 (선택)**: Firebase 서비스 계정 키(JSON)를 PC의 `backend\deploy\secrets\`에 두고 6번을 다시 실행한 뒤,
  서버 `.env`에 `FIREBASE_CREDENTIALS_PATH=/app/secrets/<파일 이름>`을 넣고 `chmod 644 secrets/*` → `docker compose up -d`.
  앱은 8번 명령에 `FIREBASE_*` 값을 더해 빌드한다 (`README.md`의 "출시 빌드")
- **아이폰**: 아이폰용 앱은 Mac에서 빌드하고 Apple 개발자 계정(유료)으로 TestFlight에 올려야 한다. 서버는 이 배포를 그대로 쓴다
- **다른 클라우드**: 스크립트는 Ubuntu + Docker면 어디서나 돈다. SSH 키로 들어가는 곳(Oracle · AWS 등)은 `-Key <키 파일> -User ubuntu`

## 막힐 때

| 증상 | 확인할 것 |
|---|---|
| `서버에 접속하지 못했어요` | 공인 IP, root 비밀번호(4번), ACG의 22번 규칙, 서버가 운영중인지 |
| `디스크 여유가 …MB예요` | 서버 스토리지가 꽉 찼다. `docker system prune -af`로 안 쓰는 이미지를 지우거나 스토리지를 늘린다 (유료) |
| `5분이 지나도 응답이 없어요` + Caddy 로그에 `challenge failed` · `timeout` | 3번의 80 · 443 규칙, DuckDNS의 IP가 서버 공인 IP와 같은지 (`nslookup`) |
| Caddy 로그에 `too many certificates` / `rateLimited` | Let's Encrypt가 같은 주소로 너무 자주 받아 잠시 막았다. 몇 시간 뒤 6번을 다시 실행 |
| 서버 로그에 `OutOfMemoryError`, 자꾸 다시 시작됨 | `free -m`으로 스왑(2GB)이 있는지. 사용자가 많아지면 메모리 2GB 이상 서버로 옮긴다 (유료) |
| 서버 로그에 DB · Redis 오류 | `docker compose ps`에서 mysql · redis가 `healthy`인지. `.env`의 `DB_PASSWORD`를 처음 값에서 바꾸면 접속이 끊긴다 |
| 앱이 "인터넷 연결을 확인해 주세요" | APK를 만들 때 넣은 주소(`-ApiBaseUrl`)가 `https://도메인`과 같은지, 브라우저로 6번의 확인 주소가 열리는지 |
