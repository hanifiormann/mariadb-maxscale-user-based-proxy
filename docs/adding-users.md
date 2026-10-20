# Yeni kullanıcı ekleme

Örnek: `3yeni` kullanıcısı `yeni2` container'ına gitsin.

## 1. DB sunucusu — hesabı oluştur

`.env` içindeki listeyi güncelleyip script'i çalıştırın:

```bash
sed -i 's/^APPUSERS=.*/APPUSERS="1eski 2eski 1yeni 2yeni 3yeni"/' .env
./db/db_users.sh
```

## 2. Proxy — filtre dosyasını yaz

```bash
cat > /etc/maxscale.cnf.d/3yeni.cnf <<'EOF'
[F-3yeni]
type=filter
module=namedserverfilter
user=3yeni
match01=/.*/
target01=yeni2
EOF
chown maxscale:maxscale /etc/maxscale.cnf.d/3yeni.cnf
```

## 3. Proxy — filtreyi zincire ekle

```bash
sed -i 's/^filters=.*/&|F-3yeni/' /etc/maxscale.cnf
grep ^filters= /etc/maxscale.cnf
systemctl restart maxscale
```

Son olarak [testing.md](testing.md) dosyasındaki okuma ve yazma testlerini yeni kullanıcı için tekrarlayın.

## Kurallar

- Filtre adı (`[F-3yeni]`) tüm dosyalarda benzersiz olmalıdır. Aynı ad iki dosyada geçerse MaxScale başlamaz.
- `target01=` değeri, `maxscale.cnf` içindeki bir sunucu bloğunun adıyla birebir aynı olmalıdır.
- **3. adım unutulursa** filtre yüklenir ama hiçbir servise bağlanmaz. Kullanıcı yine bağlanabilir, ancak tüm sorguları "Master" görünen sunucuya (eski1) gider.
- Yeni bir **backend** eklemek için `maxscale.cnf` dosyasına bir sunucu bloğu yazın ve sunucuyu hem `DB-Monitor` hem `MultiDB-Service` altındaki `servers=` satırlarına ekleyin.

## Kullanıcı silme

1. `/etc/maxscale.cnf.d/<kullanici>.cnf` dosyasını silin.
2. Adını `filters=` satırından çıkarın.
3. `systemctl restart maxscale` çalıştırın.
4. `.env` içindeki `APPUSERS` listesinden çıkarın ve DB tarafında `DROP USER` yapın.
