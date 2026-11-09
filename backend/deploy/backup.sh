#!/usr/bin/env bash
# MySQL 백업. setup-server.sh가 매일 돌도록 /etc/cron.d/backpack-backup에 걸어 둔다. 14일 치를 남긴다.
#
#   sudo bash backup.sh       → /var/backups/backpack/backpack-20261027-1900.sql.gz
#
# 되살리기:
#   gunzip -c <백업 파일> | sudo docker compose exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot backpack'
set -euo pipefail
cd "$(dirname "$0")"

dir=/var/backups/backpack
mkdir -p "$dir"
file="$dir/backpack-$(date -u +%Y%m%d-%H%M).sql.gz"
# 다 쓴 뒤에 이름을 바꿔, 실패했을 때 반쯤 쓴 파일이 백업처럼 남지 않게 한다
docker compose exec -T mysql sh -c \
	'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysqldump -uroot --single-transaction --routines backpack' |
	gzip > "$file.tmp"
mv "$file.tmp" "$file"
find "$dir" -name 'backpack-*.sql.gz' -mtime +14 -delete
echo "$file"
