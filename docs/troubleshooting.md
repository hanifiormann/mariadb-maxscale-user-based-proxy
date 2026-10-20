# Sorun giderme

Bunlar kurulum sırasında gerçekten karşılaşılan hatalar. İlk bakılacak yer her zaman MaxScale logudur:

```bash
journalctl -u maxscale -n 30 --no-pager
grep -i -E "error|warn" /var/log/maxscale/maxscale.log | tail -20
```

| Belirti | Sebep | Çözüm |
|---|---|---|
| `maxscale: No such file or directory` | Paket kurulu değil, sadece config dosyası kalmış | `dnf install -y maxscale` |
| Tüm sunucular `Auth Error, Down` | DB'lerde `maxscale` kullanıcısı yok veya şifre yanlış | `db/db_users.sh`. Proxy'den `mariadb -h <DB> -P 3306 -umaxscale -p` ile doğrulayın. |
| İstemci: `Access denied for user '1eski'@'127.0.0.1'` | MaxScale kullanıcı listesini çekemiyor ya da kullanıcı backend'de yok | Önce sunucuların `Running` olduğunu, sonra kullanıcıyı kontrol edin |
| `db_users.sh` sonrası kullanıcılar oluşmamış | SQL `-e` ile verilince `--force` çalışmıyor, ilk `DROP USER` hatasında duruyor | SQL'i stdin'den verin (repodaki script böyle yapıyor) |
| 10.5+ sunucularda `Auth Error, Running` | Logda `SHOW SLAVE STATUS ... you need SLAVE MONITOR privilege` | `GRANT SLAVE MONITOR, BINLOG MONITOR ON *.* TO 'maxscale'@'%';` |
| `Missing slashes (/) around a regular expression is deprecated` | `match01=.*` eski yazım | `match01=/.*/` |
| `The MaxScale GUI is enabled but encryption ... is not enabled` | GUI açık ama HTTPS yok | `[maxscale]` altına `admin_gui=false` |
| `does not support MariaDB gtid` (5.5) | 5.5'te GTID yok | Normal, bir şey yapmaya gerek yok |
| Bir sunucu `Down` | Container durmuş veya port/firewall kapalı | DB'de `podman ps`, proxy'de `nc -zv <DB> <port>` |
| Tüm yazmalar eski1'e gidiyor | Kullanıcının filtresi yok ya da `filters=` satırında değil | `maxctrl list filters`, `grep ^filters= /etc/maxscale.cnf` |
| MaxScale başlamıyor | Config sözdizimi hatası veya aynı bölüm adı iki kez tanımlı | `journalctl -u maxscale` içindeki satır numarasına bakın |
| `match_user_to_server` hatası | Böyle bir MaxScale parametresi yok | Kullanıcı bazlı yönlendirme için `namedserverfilter` + `user=` kullanın |

## Faydalı komutlar

```bash
maxctrl list servers                  # Sunucu durumları
maxctrl list services                 # Servisler
maxctrl list filters                  # Filtreler ve bağlı oldukları servis
maxctrl list sessions                 # Açık oturumlar
maxctrl show filter F-1yeni           # Bir filtrenin parametreleri
maxctrl show service MultiDB-Service
```
