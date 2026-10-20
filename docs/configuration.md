# Config dosyalarının açıklaması

MaxScale config'i `[bölüm_adı]` başlıklı bloklardan oluşur. Her bloğun `type=` satırı ne olduğunu söyler: `server`, `monitor`, `service`, `listener` veya `filter`. Bölüm adları tüm dosyalarda benzersiz olmalıdır, çünkü bloklar birbirine bu adlarla referans verir.

## proxy/maxscale.cnf

### `[maxscale]` — global ayarlar

| Satır | Anlamı |
|---|---|
| `threads=auto` | Worker thread sayısı, CPU çekirdek sayısı kadar |
| `admin_host=127.0.0.1` | REST API sadece sunucunun kendisinden erişilebilir. `maxctrl` bu API'yi kullanır. |
| `admin_port=8989` | REST API portu |
| `admin_gui=false` | Web arayüzünü kapatır. Açık kalırsa HTTPS istediği için her açılışta uyarı verir. |

### `[eski1]` … `[yeni2]` — backend sunucular

| Satır | Anlamı |
|---|---|
| `[eski1]` | Sunucunun MaxScale içindeki adı. `servers=`, `target01=` ve `maxctrl` bu adı kullanır. |
| `type=server` | Bu blok bir backend'dir. |
| `address=` | DB sunucusunun IP'si. Podman'ın iç IP'si (10.88.x.x) değil. |
| `port=` | Container'ın host'a açılan portu |

`protocol=` yazılmaz. 24.02'de varsayılan değer doğrudur. Eski sürümlerden kalma `protocol=MySQLBackend` gerekmez.

### `[DB-Monitor]`

| Satır | Anlamı |
|---|---|
| `module=mariadbmon` | Sunuculara düzenli bağlanıp durumlarını belirler: `Running`, `Down`, `Master`, `Auth Error` |
| `servers=` | İzlenecek sunucular |
| `user=` / `password=` | Monitör hesabı |
| `monitor_interval=2000ms` | 2 saniyede bir kontrol |

### `[MultiDB-Service]`

| Satır | Anlamı |
|---|---|
| `router=readwritesplit` | Filtrelerin eklediği routing hint'lere uyar |
| `servers=` | Servisin kullanabileceği sunucular. Filtre hedefleri bu listede olmalıdır. |
| `user=` / `password=` | Backend'lerden kullanıcı listesinin çekildiği hesap. İstemci şifreleri bu listeyle doğrulanır. |
| `filters=F-1eski\|F-2eski\|…` | Filtre zinciri, `\|` ile ayrılır. **Joker kabul etmez**, her yeni filtre buraya eklenir. |
| `master_failure_mode=fail_on_write` | Master kaybolursa oturum kapanmaz. Okumalar devam eder, sadece ipucusuz yazmalar hata verir. |

### `[MultiDB-Listener]`

| Satır | Anlamı |
|---|---|
| `service=MultiDB-Service` | Bağlantıların devredileceği servis |
| `port=4006` | Dinlenen port. `address=` yazılmadığı için tüm arayüzlerde dinler. |

## proxy/maxscale.cnf.d/&lt;kullanici&gt;.cnf

```ini
[F-1yeni]
type=filter
module=namedserverfilter
user=1yeni
match01=/.*/
target01=yeni1
```

| Satır | Anlamı |
|---|---|
| `[F-1yeni]` | Filtre adı. Genel config'teki `filters=` satırında aynen yazılır. |
| `module=namedserverfilter` | Sorgulara "şu sunucuya git" ipucu ekleyen modül |
| `user=1yeni` | Filtre **sadece** bu kullanıcının oturumlarında çalışır |
| `match01=/.*/` | PCRE2 düzenli ifade. `.*` her sorguyla eşleşir. 24.02'de eğik çizgiler gerekir, yazılmazsa uyarı verir. |
| `target01=yeni1` | Hedef sunucu bloğunun adı |

İnce ayar için `match02`/`target02` gibi ek çiftler (örneğin sadece belirli tablolar) veya istemci IP'sine göre kısıtlamak için `source=` eklenebilir.

## db/db_users.sh

| Adım | Ne yapar |
|---|---|
| CLI seçimi | 5.5 imajında `mariadb` komutu yok, `mysql` kullanılır |
| Silme | `dbuser`, `maxscale` ve uygulama kullanıcılarını siler. 5.5'te `IF EXISTS` olmadığı için `--force` ile. |
| Oluşturma | Yeni sürümlerde `CREATE USER`, 5.5'te `GRANT ... IDENTIFIED BY` |
| `maxscale` yetkileri | `SELECT ON mysql.*`, `SHOW DATABASES`, `REPLICATION CLIENT`. 10.5+ için ayrıca `SLAVE MONITOR`, `BINLOG MONITOR`. |
| Uygulama yetkileri | `ALL ON testdb.*` |

**Dikkat:** SQL `-e` ile değil stdin'den verilir. `-e` ile verildiğinde `--force` çalışmaz ve olmayan bir kullanıcıyı silmeye çalışırken kalan tüm komutlar atlanır.

### `maxscale` hesabının yetkileri neden gerekli

| Yetki | Neden |
|---|---|
| `SELECT ON mysql.*` | İstemci şifrelerini doğrulamak için kullanıcı tablolarını okur |
| `SHOW DATABASES` | Kullanıcının erişebildiği veritabanlarını kontrol eder |
| `REPLICATION CLIENT` | 5.5'te monitörün durum sorguları için |
| `SLAVE MONITOR`, `BINLOG MONITOR` | MariaDB 10.5+ — olmadan sunucu `Auth Error` görünür |
