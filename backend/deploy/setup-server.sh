#!/usr/bin/env bash
# 클라우드 VM(Ubuntu)에서 Backpack 서버를 띄운다. 처음 설치와 업데이트 모두 이걸로 한다.
# PC의 scripts/deploy-cloud.ps1이 이 폴더와 app.jar를 올린 뒤 실행한다. VM에서 직접 실행해도 된다:
#
#   sudo DOMAIN=backpack-xxxx.duckdns.org bash setup-server.sh
#
# DOMAIN은 처음 한 번만 주면 .env에 남는다. DB · Redis 비밀번호와 JWT 키도 처음에 한 번 만들어 .env에 둔다.
set -euo pipefail
cd "$(dirname "$0")"

if [ "$(id -u)" -ne 0 ]; then
	echo "sudo로 실행해 주세요: sudo bash $0" >&2
	exit 1
fi
if [ ! -f app.jar ]; then
	echo "app.jar가 없어요. PC에서 scripts/deploy-cloud.ps1로 올려 주세요." >&2
	exit 1
fi

echo "== 1/5 Docker"
if ! docker compose version >/dev/null 2>&1; then
	apt-get update -q
	if ! DEBIAN_FRONTEND=noninteractive apt-get install -y -q docker.io docker-compose-v2; then
		# 오래된 Ubuntu(20.04 등)에는 docker-compose-v2 꾸러미가 없다. Docker 공식 저장소에서 설치한다
		DEBIAN_FRONTEND=noninteractive apt-get install -y -q ca-certificates curl
		install -m 0755 -d /etc/apt/keyrings
		curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
		echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc]" \
			"https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
			> /etc/apt/sources.list.d/docker.list
		apt-get update -q
		DEBIAN_FRONTEND=noninteractive apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-compose-plugin
	fi
	systemctl enable --now docker
fi

echo "== 2/5 방화벽 · 메모리"
# Oracle Cloud의 Ubuntu 이미지는 VM 안의 iptables가 22번 말고는 모두 막는다 (INPUT 끝의 REJECT).
# 클라우드 콘솔의 보안 목록과 따로라서 둘 다 열어야 한다. REJECT가 없는 VM에서는 건너뛴다
if command -v iptables >/dev/null; then
	reject_line=$(iptables -L INPUT --line-numbers -n | awk '$2 == "REJECT" { print $1; exit }')
	if [ -n "$reject_line" ]; then
		for port in 80 443; do
			if ! iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; then
				iptables -I INPUT "$reject_line" -p tcp --dport "$port" -j ACCEPT
			fi
		done
		if command -v netfilter-persistent >/dev/null; then
			netfilter-persistent save >/dev/null
		fi
	fi
fi
# 메모리 1GB짜리 서버(네이버 클라우드 Micro 등)에서는 MySQL과 서버가 함께 뜨지 못한다. 2GB 스왑을 만든다
mem_mb=$(awk '/MemTotal/ { print int($2 / 1024) }' /proc/meminfo)
# 디스크가 작으면(Micro 10GB) 이미지를 받다 멈추므로 먼저 알린다
free_mb=$(df -m --output=avail / | tail -1 | tr -d ' ')
if [ "$free_mb" -lt 3000 ]; then
	echo "디스크 여유가 ${free_mb}MB예요. 3GB 이상 있어야 이미지를 받을 수 있어요." >&2
	exit 1
fi
if [ "$mem_mb" -lt 2048 ] && [ ! -f /swapfile ]; then
	fallocate -l 2G /swapfile
	chmod 600 /swapfile
	mkswap /swapfile >/dev/null
	swapon /swapfile
	echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "== 3/5 설정 (.env)"
secret() { head -c "$1" /dev/urandom | od -An -tx1 | tr -d ' \n'; }
if [ ! -f .env ]; then
	if [ -z "${DOMAIN:-}" ]; then
		echo "처음 설치할 때는 DOMAIN이 필요해요: sudo DOMAIN=backpack-xxxx.duckdns.org bash $0" >&2
		exit 1
	fi
	(
		umask 077
		cat > .env <<EOF
# setup-server.sh가 만들었다. 비밀 값이 들어 있으니 밖으로 내보내지 않는다.
# 바꾼 뒤에는 sudo docker compose up -d 로 다시 띄운다 (DB_PASSWORD · MYSQL_ROOT_PASSWORD는 처음 값 그대로 둔다)
DOMAIN=$DOMAIN
DB_PASSWORD=$(secret 24)
MYSQL_ROOT_PASSWORD=$(secret 24)
REDIS_PASSWORD=$(secret 24)
JWT_SECRET=$(secret 48)
# 한국수출입은행 환율 API 인증키 (선택)
EXIM_API_KEY=
# AI 일정 재구성 Gemini 키 (선택, https://aistudio.google.com/apikey 에서 무료)
GEMINI_API_KEY=
# 구글 지도 서버 키 (선택, docs/google-maps.md). 없으면 OpenStreetMap을 쓴다
GOOGLE_MAPS_API_KEY=
# 푸시 (선택): secrets/에 둔 Firebase 서비스 계정 키. 예: /app/secrets/backpack-firebase-adminsdk.json
FIREBASE_CREDENTIALS_PATH=
EOF
		# 메모리가 2GB보다 작으면 서버 · MySQL이 쓰는 메모리를 줄인다
		if [ "$mem_mb" -lt 2048 ]; then
			cat >> .env <<'EOF'
# 메모리 1GB 서버용 (setup-server.sh가 넣었다)
JAVA_TOOL_OPTIONS=-Xms96m -Xmx320m -XX:MaxMetaspaceSize=160m -XX:+UseSerialGC
MYSQL_BUFFER_POOL=64M
EOF
		fi
	)
elif [ -n "${DOMAIN:-}" ]; then
	sed -i "s|^DOMAIN=.*|DOMAIN=$DOMAIN|" .env
fi
# PC의 backend/.env에서 넘겨준 API 키(deploy-cloud.ps1)를 넣는다. 넘겨주지 않은 키는 그대로 둔다
for name in GEMINI_API_KEY GOOGLE_MAPS_API_KEY EXIM_API_KEY; do
	value="${!name:-}"
	if [ -n "$value" ]; then
		if grep -q "^$name=" .env; then
			sed -i "s|^$name=.*|$name=$value|" .env
		else
			echo "$name=$value" >> .env
		fi
	fi
done
domain=$(sed -n 's/^DOMAIN=//p' .env)
mkdir -p secrets

echo "== 4/5 서버 시작 (처음에는 이미지를 받느라 몇 분 걸려요)"
# 큰 이미지(MySQL 등)는 받다가 연결이 끊길 때가 있다. 받은 층은 남으므로 다시 받으면 이어서 받는다
for attempt in 1 2 3; do
	if docker compose pull --quiet --ignore-buildable; then
		break
	fi
	if [ "$attempt" = 3 ]; then
		echo "이미지를 받지 못했어요. 인터넷 연결을 확인하고 다시 실행해 주세요." >&2
		exit 1
	fi
	echo "이미지를 받다가 끊겼어요. 다시 받아요 ($attempt/3)"
	sleep 5
done
docker compose up -d --build --remove-orphans
docker image prune -f >/dev/null

# 매일 한국 시간 새벽 4시(UTC 19시)에 DB를 백업한다 (backup.sh)
cat > /etc/cron.d/backpack-backup <<EOF
0 19 * * * root bash $(pwd)/backup.sh >/dev/null 2>&1
EOF

echo "== 5/5 확인: https://$domain"
# 잘못된 토큰에 401이 오면 HTTPS 인증서 · 서버 · DB가 모두 준비된 것이다 (scripts/smoke-boot.sh와 같은 방법).
# 이 VM의 Caddy로 바로 보낸다. 인증서는 Let's Encrypt가 밖에서 이 VM에 접속해 확인한 뒤에야 나오므로
# 인증서가 있으면 밖에서도 닿는다는 뜻이다
curl_args=(-s -o /dev/null -w '%{http_code}' --max-time 5 --resolve "$domain:443:127.0.0.1"
	-H 'Authorization: Bearer invalid')
if [ "$domain" = localhost ]; then
	curl_args+=(-k) # 시험용: Caddy가 스스로 서명한 인증서
fi
for _ in $(seq 1 60); do
	status=$(curl "${curl_args[@]}" "https://$domain/api/trips" || true)
	if [ "$status" = "401" ]; then
		echo "준비됐어요: https://$domain"
		exit 0
	fi
	sleep 5
done

echo "5분이 지나도 응답이 없어요. 아래 로그를 확인해 주세요 (docs/deploy-cloud.md의 '막힐 때')." >&2
docker compose ps
docker compose logs --tail 40 caddy backend
exit 1
