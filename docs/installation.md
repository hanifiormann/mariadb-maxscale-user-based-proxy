# Kurulum

Örnek IP'ler: DB sunucusu `192.0.2.10`, proxy `192.0.2.20`. Kendi değerlerinizi `.env` dosyasına ve `proxy/maxscale.cnf` içine yazın.

## 1. DB sunucusu

```bash
git clone https://github.com/hanifiormann/mariadb-maxscale-user-based-proxy.git
cd mariadb-maxscale-user-based-proxy
cp .env.example .env && vi .env

./db/containers.sh      # 4 container: eski1/eski2 (5.5), yeni1/yeni2 (latest)
./db/db_users.sh        # maxscale + uygulama kullanıcıları
```

Her container için beş kullanıcı görmelisiniz: `maxscale`, `1eski`, `2eski`, `1yeni`, `2yeni`.

Portları sadece proxy'ye açın:

```bash
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.0.2.20" port port="3306-3309" protocol="tcp" accept'
firewall-cmd --reload
```

## 2. Proxy sunucusu

```bash
# MaxScale reposu ve paketler
curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | bash -s -- --skip-server --skip-tools
dnf install -y maxscale mariadb nmap-ncat
maxscale --version

# Erişim kontrolü
for p in 3306 3307 3308 3309; do nc -zv 192.0.2.10 $p; done

# Config
git clone https://github.com/hanifiormann/mariadb-maxscale-user-based-proxy.git
cd mariadb-maxscale-user-based-proxy
cp proxy/maxscale.cnf /etc/maxscale.cnf
mkdir -p /etc/maxscale.cnf.d
cp proxy/maxscale.cnf.d/*.cnf /etc/maxscale.cnf.d/
chown -R maxscale:maxscale /etc/maxscale.cnf.d

# /etc/maxscale.cnf: address= ve iki password= satırını düzenleyin
vi /etc/maxscale.cnf

systemctl enable --now maxscale
maxctrl list servers
maxctrl list filters
```

Dört sunucunun da `Running` görünmesi gerekiyor. Ardından [testing.md](testing.md) dosyasındaki testleri çalıştırın.

## Canlıya geçmeden önce

- [ ] DB portları (3306–3309) sadece proxy'ye açık
- [ ] Proxy portu (4006) sadece uygulama sunucularına açık
- [ ] Tüm örnek şifreler değişti, uygulama kullanıcılarına ayrı şifreler verildi
- [ ] `maxkeys` + `maxpasswd` ile config'teki şifreler şifrelendi
- [ ] Container'lara volume bağlandı (`-v /data/eski1:/var/lib/mysql:Z`)
- [ ] `-p<şifre>` içeren komutlar shell geçmişinden temizlendi
- [ ] MariaDB 5.5 için taşıma planı var (artık güvenlik güncellemesi almıyor)
