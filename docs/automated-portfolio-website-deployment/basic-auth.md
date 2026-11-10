### Basic Auth Ekleme

Bir önceki adımda env değişkenlerini eklemenin bir yolunu gördün. Diğer adım da bir başlangıç scripti ile env eklemek. 

`/docker-entrypoint.d/` klasörüne bir `.sh` dosyası koy, nginx başlamadan hemen önce bu script çalışır. 

 Script `$BASIC_AUTH_USER` gibi değişkenleri okuyup istediği işi yapabilir. Bu yöntemi değerden bir dosya üretmemiz gerektiği için kullanıyoruz: `htpasswd`

1. Yol Template ile: nginx ayarına `auth_basic` satırlarını eklersin.
2. Yol Script ile: `/docker-entrypoint.d/` klasörüne bir script koyarsın. Script `BASIC_AUTH_USER` ve `BASIC_AUTH_PASS` değişkenlerini okuyup `htpasswd` dosyasını üretir.

Limiting access to resources by validating the user name and password using the “HTTP Basic Authentication” protocol. 
https://nginx.org/en/docs/http/ngx_http_auth_basic_module.html

https://www.getpagespeed.com/server-setup/nginx/nginx-basic-auth-htpasswd
When a client requests a protected resource, NGINX checks for the Authorization header. If missing, it returns a 401 Unauthorized response.

The browser then sends credentials as a `Base64-encoded username:password` string. NGINX decodes this and compares the password hash against entries in your `htpasswd file`.

The `htpasswd` utility comes with the Apache HTTP server tools package. Despite its Apache origins, it’s the standard tool for creating password files compatible with NGINX basic auth.

On Alpine Linux:
```bash
apk add apache2-utils
```

```1. Bunu Dockerfile'a ekleyeceğiz:```

```dockerfile
#declare the base image
FROM nginx:alpine

#install htpasswd
RUN apk add --no-cache apache2-utils

# --no-cache: İndirilen paket listesini image'da saklamaz, image'ı küçük tutar.
```

`2. 40-basic-auth.sh scriptini oluştur:`

```bash
#!/bin/sh
set -e

if [ -z "$BASIC_AUTH_USER" ] || [ -z "$BASIC_AUTH_PASS" ]; then
    echo "ERROR: BASIC_AUTH_USER and BASIC_AUTH_PASS must be set" >&2
    exit 1
fi

htpasswd -bc /etc/nginx/.htpasswd "$BASIC_AUTH_USER" "$BASIC_AUTH_PASS"
```

`-b`: Şifreyi komut satırından alır. Bu seçenek olmasa `htpasswd` şifreyi klavyeden sormaya çalışır. Container başlarken klavye olmadığı için script orada takılırdı.

`3.  Image'ı build et`

```bash
docker build -t portfolio-htpasswd .

docker images portfolio-htpasswd
```

`4- Container'ı çalıştır ve test et:`

- 8080 portunu boşalt bir container 8080 portunu kullanıyor olabilir:

```bash
docker rm -f portfolio portfolio-htpasswd 2>/dev/null

#2>/dev/null ifadesi, container yoksa çıkacak "No such container" hatasını gizler.
```

- Container'ı başlat:

```bash
docker run -d --rm --name portfolio-htpasswd -p 8080:80 --env-file .env portfolio-htpasswd
```
- Script'in çalıştığını loglarda gör:

```bash
docker logs portfolio-htpasswd
```
- Çıktıda şu iki satırı arıyorsun:
    - /docker-entrypoint.sh: Launching /docker-entrypoint.d/40-basic-auth.sh
    - Adding password for user gizem
    - İkinci satırı htpasswd yazıyor. Bu satır, dosyanın oluşturulduğunu gösteriyor.

- Oluşturulan dosyaya bak:

```bash
docker exec portfolio-htpasswd cat /etc/nginx/.htpasswd
```

- Basic auth'u test et. Birkaç saniye bekle, sonra:

```bash
curl -s -o /dev/null -w "%{http_code}\n" -u gizem:<sifren> localhost:8080        # 200 beklenir
```

- gizem ve `<sifren>` yerine .env dosyandaki değerleri yaz.

- Tarayıcıda dene: Gizli pencerede http://localhost:8080 adresini aç, şifre sormalı.

The htpasswd command creates and manages password files. Here’s how to create a new file with your first user:
htpasswd -c /etc/nginx/.htpasswd admin
The -c flag creates a new file (overwriting any existing one). You’ll be prompted to enter and confirm the password:
New password:
Re-type new password:
Adding password for user admin
Important: Only use -c when creating a new file. Using it on an existing file will erase all other users.

To add more users to an existing file, omit the -c flag:
htpasswd /etc/nginx/.htpasswd developer
For scripts and automation, use the -b flag to provide the password on the command line:
htpasswd -b /etc/nginx/.htpasswd api_user MySecurePassword123

Security note: This exposes the password in your shell history and process list. For better security in scripts, use the -i flag to read from stdin:
echo "MySecurePassword123" | htpasswd -i /etc/nginx/.htpasswd api_user
