# Test

En hızlı yol, proxy sunucusunda `./scripts/test_routing.sh` çalıştırmak. Script monitörü, okuma yönlendirmesini ve yazma yönlendirmesini kontrol eder, sonunda tek satırlık bir sonuç yazar.

Aşağıda aynı testlerin elle nasıl yapıldığı var.

## 1. Ağ ve MaxScale hesabı

```bash
for p in 3306 3307 3308 3309; do nc -zv 192.0.2.10 $p; done
mariadb -h 192.0.2.10 -P 3306 -umaxscale -p -e "SELECT 1;"
mariadb -h 192.0.2.10 -P 3308 -umaxscale -p -e "SELECT 1;"
```

Beklenen sonuç: dört portta `Connected`, iki sorguda da `1`.

## 2. Monitör

```bash
maxctrl list servers
maxctrl list filters
```

| Sunucu | Beklenen durum |
|---|---|
| eski1 | Master, Running |
| eski2 | Running |
| yeni1 | Running |
| yeni2 | Running |

`Auth Error` veya `Down` görülmemelidir. Dört filtrenin de `MultiDB-Service`'e bağlı olması gerekir.

## 3. Okuma yönlendirmesi

```bash
for u in 1eski 2eski 1yeni 2yeni; do
  echo "== $u =="
  mariadb -h 127.0.0.1 -P 4006 -u$u -p -e "SELECT @@version, @@hostname;"
done
```

Örnek çıktı (test ortamı):

| Kullanıcı | @@version | @@hostname |
|---|---|---|
| 1eski | 5.5.64-MariaDB-1~trusty | c9bc9fa83fee |
| 2eski | 5.5.64-MariaDB-1~trusty | fb4c34e97eec |
| 1yeni | 13.0.2-MariaDB-ubu2604 | 36d6301278fc |
| 2yeni | 13.0.2-MariaDB-ubu2604 | 2c9e26b277b1 |

Sürüm eski/yeni ayrımını, hostname (container ID'si) ise hangi container'a gidildiğini gösterir. Dört hostname birbirinden farklı olmalıdır.

## 4. Yazma yönlendirmesi

Her kullanıcı MaxScale üzerinden kendi satırını yazar:

```bash
for u in 1eski 2eski 1yeni 2yeni; do
  mariadb -h 127.0.0.1 -P 4006 -u$u -p testdb -e "
  CREATE TABLE IF NOT EXISTS kim (u VARCHAR(20), h VARCHAR(64));
  INSERT INTO kim VALUES ('$u', @@hostname);"
done
```

Sonra MaxScale atlanarak her backend'e doğrudan bakılır:

```bash
for p in 3306 3307 3308 3309; do
  echo "== port $p"
  mariadb -h 192.0.2.10 -P $p -u1eski -p testdb -N -e "SELECT * FROM kim;"
done
```

Her backend'de **sadece** kendi kullanıcısının satırı olmalıdır: 3306'da 1eski, 3307'de 2eski, 3308'de 1yeni, 3309'da 2yeni. Tüm satırlar tek bir backend'de toplanmışsa filtreler çalışmıyordur.

## 5. Log

```bash
grep -i -E "error|warn" /var/log/maxscale/maxscale.log | tail -20
```

Kabul edilebilir tek uyarı: `Server 'eski1' (5.5.64...) does not support MariaDB gtid`. Bu normaldir, çünkü 5.5'te GTID yok.
