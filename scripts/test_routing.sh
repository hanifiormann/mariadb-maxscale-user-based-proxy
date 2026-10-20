#!/bin/bash
# Uçtan uca yönlendirme testi. Proxy sunucusunda çalıştırın.
#  1) Monitör durumu   2) Okuma yönlendirmesi   3) Yazma yönlendirmesi
set -uo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && source .env
: "${DB_HOST:?DB_HOST tanımlı değil (.env)}"
: "${APPPASS:?APPPASS tanımlı değil (.env)}"
PROXY="${PROXY_LOCAL:-127.0.0.1}"
PORT="${PROXY_PORT:-4006}"
DB="${DB:-testdb}"
FAIL=0

# kullanici:beklenen_backend_portu
MAP="1eski:3306 2eski:3307 1yeni:3308 2yeni:3309"

echo "== 1) Monitör"
maxctrl list servers
if maxctrl list servers | grep -q -E "Auth Error|Down"; then
  echo "HATA: Auth Error veya Down durumunda sunucu var"; FAIL=1
fi

echo; echo "== 2) Okuma: MaxScale üzerinden gelen hostname, backend'in kendi hostname'iyle aynı mı?"
for pair in $MAP; do
  u=${pair%%:*}; p=${pair##*:}
  via=$(mariadb -h "$PROXY" -P "$PORT" -u"$u" -p"$APPPASS" -N -e "SELECT @@hostname" 2>&1)
  direct=$(mariadb -h "$DB_HOST" -P "$p" -u"$u" -p"$APPPASS" -N -e "SELECT @@hostname" 2>&1)
  ver=$(mariadb -h "$PROXY" -P "$PORT" -u"$u" -p"$APPPASS" -N -e "SELECT @@version" 2>&1)
  if [ "$via" = "$direct" ]; then echo "OK    $u → port $p ($via, $ver)"
  else echo "HATA  $u: proxy=$via, beklenen=$direct"; FAIL=1; fi
done

echo; echo "== 3) Yazma: her kullanıcı kendi satırını yazar, sonra backend'lere doğrudan bakılır"
for pair in $MAP; do
  u=${pair%%:*}
  mariadb -h "$PROXY" -P "$PORT" -u"$u" -p"$APPPASS" "$DB" -e "
    CREATE TABLE IF NOT EXISTS routing_test (u VARCHAR(20), h VARCHAR(64));
    DELETE FROM routing_test;
    INSERT INTO routing_test VALUES ('$u', @@hostname);"
done
for pair in $MAP; do
  u=${pair%%:*}; p=${pair##*:}
  rows=$(mariadb -h "$DB_HOST" -P "$p" -u"$u" -p"$APPPASS" "$DB" -N -e "SELECT u FROM routing_test" 2>&1 | tr '\n' ' ')
  if [ "$rows" = "$u " ]; then echo "OK    port $p yalnızca '$u' satırını içeriyor"
  else echo "HATA  port $p: bulunan satırlar: $rows"; FAIL=1; fi
done

# Temizlik
for pair in $MAP; do
  u=${pair%%:*}
  mariadb -h "$PROXY" -P "$PORT" -u"$u" -p"$APPPASS" "$DB" -e "DROP TABLE IF EXISTS routing_test;"
done

echo
[ $FAIL = 0 ] && echo "SONUÇ: Tüm testler geçti." || echo "SONUÇ: Hata var, yukarıya bakın."
exit $FAIL
