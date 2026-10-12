#!/usr/bin/env bash
# 빌드된 jar를 띄워 기동 여부를 확인한다. DB_URL, JWT_SECRET 등은 호출하는 쪽에서 환경변수로 준다.
# 잘못된 토큰에 401을 돌려주면 Flyway 적용과 스키마 검증을 통과해 요청을 받는 상태다.
# (토큰 없는 요청은 보안 설정에 따라 결과가 달라지므로 쓰지 않는다)
set -u

PORT="${SERVER_PORT:-8080}"
JAR=$(ls build/libs/*.jar | grep -v -- '-plain.jar$' | head -n 1)
LOG=$(mktemp)

SERVER_PORT="$PORT" java -jar "$JAR" > "$LOG" 2>&1 &
APP_PID=$!
trap 'kill "$APP_PID" 2>/dev/null' EXIT

for _ in $(seq 1 60); do
	if ! kill -0 "$APP_PID" 2>/dev/null; then
		break # 기동 실패로 프로세스가 이미 종료됨
	fi
	status=$(curl -s -o /dev/null -w '%{http_code}' -H 'Authorization: Bearer invalid' \
		"http://127.0.0.1:$PORT/api/trips" || true)
	if [ "$status" = "401" ]; then
		echo "기동 확인: 잘못된 토큰에 401로 응답"
		exit 0
	fi
	sleep 1
done

echo "기동 실패. 애플리케이션 로그:"
cat "$LOG"
exit 1
