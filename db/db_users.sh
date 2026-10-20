#!/bin/bash
# MaxScale için backend kullanıcılarını dört container'da sıfırdan kurar.
# İstediğiniz kadar tekrar çalıştırılabilir. Değerler .env dosyasından okunur.
set -uo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && source .env
: "${ROOTPASS:?ROOTPASS tanımlı değil (.env)}"
: "${MAXPASS:?MAXPASS tanımlı değil (.env)}"
: "${APPPASS:?APPPASS tanımlı değil (.env)}"
MAXUSER="${MAXUSER:-maxscale}"
APPUSERS="${APPUSERS:-1eski 2eski 1yeni 2yeni}"
DB="${DB:-testdb}"

for c in eski1 eski2 yeni1 yeni2; do
  # 5.5 imajında 'mariadb' komutu yok, 'mysql' var
  if podman exec "$c" which mariadb >/dev/null 2>&1; then
    CLI=mariadb; NEW=1
  else
    CLI=mysql;   NEW=0
  fi

  SQL=""
  # 1) Eski kullanıcıları sil (5.5'te IF EXISTS yok; --force hatayı atlar)
  for u in dbuser $MAXUSER $APPUSERS; do
    if [ $NEW = 1 ]; then SQL+="DROP USER IF EXISTS '$u'@'%';"$'\n'
    else                  SQL+="DROP USER '$u'@'%';"$'\n'; fi
  done

  # 2) Yeni sürümlerde kullanıcıları açıkça oluştur
  if [ $NEW = 1 ]; then
    SQL+="CREATE USER '$MAXUSER'@'%' IDENTIFIED BY '$MAXPASS';"$'\n'
    for u in $APPUSERS; do SQL+="CREATE USER '$u'@'%' IDENTIFIED BY '$APPPASS';"$'\n'; done
  fi

  # 3) MaxScale hesabı: kullanıcı listesini okuma + monitör yetkileri
  SQL+="GRANT SELECT ON mysql.* TO '$MAXUSER'@'%' IDENTIFIED BY '$MAXPASS';"$'\n'
  SQL+="GRANT SHOW DATABASES, REPLICATION CLIENT ON *.* TO '$MAXUSER'@'%';"$'\n'
  # MariaDB 10.5+ : REPLICATION CLIENT bölündü, monitör bunlar olmadan Auth Error verir
  [ $NEW = 1 ] && SQL+="GRANT SLAVE MONITOR, BINLOG MONITOR ON *.* TO '$MAXUSER'@'%';"$'\n'

  # 4) Uygulama kullanıcıları (readwritesplit tüm backend'lere bağlandığı için hepsi her yerde)
  for u in $APPUSERS; do
    SQL+="GRANT ALL ON $DB.* TO '$u'@'%' IDENTIFIED BY '$APPPASS';"$'\n'
  done
  SQL+="FLUSH PRIVILEGES;"

  # SQL stdin'den verilir: -e ile verilirse --force çalışmaz, ilk hatada durur
  echo "$SQL" | podman exec -i "$c" $CLI -uroot -p"$ROOTPASS" --force 2>&1 | grep -v "DROP USER failed"

  echo "== $c kullanıcıları:"
  podman exec -i "$c" $CLI -uroot -p"$ROOTPASS" -N -e \
    "SELECT user,host FROM mysql.user WHERE user NOT IN ('root','','healthcheck','mariadb.sys');"
done
