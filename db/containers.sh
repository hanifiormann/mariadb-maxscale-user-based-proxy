#!/bin/bash
# DB sunucusunda dört MariaDB container'ı oluşturur.
# Not: volume bağlanmıyor; container silinirse veri de silinir.
# Canlı kullanım için her container'a -v <dizin>:/var/lib/mysql:Z ekleyin.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && source .env
: "${ROOTPASS:?ROOTPASS tanımlı değil (.env)}"
DB="${DB:-testdb}"

# Eski sürüm (MariaDB 5.5) — MYSQL_* değişkenleri
for spec in eski1:3306 eski2:3307; do
  name=${spec%%:*}; port=${spec##*:}
  podman run -d --name "$name" -p "$port:3306" \
    -e MYSQL_ROOT_PASSWORD="$ROOTPASS" -e MYSQL_DATABASE="$DB" \
    docker.io/library/mariadb:5.5
done

# Yeni sürüm (MariaDB latest) — MARIADB_* değişkenleri
for spec in yeni1:3308 yeni2:3309; do
  name=${spec%%:*}; port=${spec##*:}
  podman run -d --name "$name" -p "$port:3306" \
    -e MARIADB_ROOT_PASSWORD="$ROOTPASS" -e MARIADB_DATABASE="$DB" \
    docker.io/library/mariadb:latest
done

echo "Container'ların açılması bekleniyor..."
sleep 15
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
