# Environment Variable Ekleme

Verdiğin ortam değişkenlerini NGINX okuyacak. Kullanacağın değişkenler de BASIC_AUTH'un kullanıcı adı ve şifresi. Burda mantık şu aynı image'ı farklı değerlerle çalıştırıyorsun.

Container'a bağlanmak için:

```bash
docker exec -it portfolio /bin/sh
```

Container'a bağlandın. Gördüğün ilk path `/usr/share/nginx/html #` olacak.

Şimdi NGINX image'ı container'ı başlatırken `/etc/nginx/templates/` klasöründeki `*.template` dosyalarını okur.
Environment variable'ları gerçek değerleriyle değiştirir ve sonucu `/etc/nginx/conf.d/default.conf` klasörüne yazar.

Bu dönüşümü Nginx'in resmi Docker image'ındaki `20-envsubst-on-templates.sh` script'i gerçekleştiriyor

`*.template` dediğimiz şey de benim oluşturduğum `default.conf.template` o yüzden `default.conf` dosyasına yazıyor.
Ben burda `add_header X-App-Env "${APP_ENV}";` ile ekledim.

NGINX Docker image'ının başlangıç script'i `${APP_ENV}` ifadesini dev ile değiştirir.

bunu ben yazdım: `/etc/nginx/templates/default.conf.template` -> `add_header X-App-Env "${APP_ENV}";`

bu da otomatik oluşturuldu: `/etc/nginx/conf.d/default.conf` envsubst ile.

```nginx
add_header X-App-Env "dev";
```

Sonuç olarak HTTP Response Header `X-App-Env: dev` olarak döner.

Document: https://hub.docker.com/_/nginx#using-environment-variables-in-nginx-configuration-new-in-119

> By default, this function reads template files in
> `/etc/nginx/templates/*.template`
> and outputs the result of executing envsubst to
> `/etc/nginx/conf.d`

- Base image: Statik site için nginx:alpine seçtim. 
- Basic auth: nginx'in auth_basic özelliğini ve bir htpasswd dosyasını kullandım.

- Ortam değişkenleri: Kullanıcı adı ve şifre image'ın içine gömmedim. Bunları container başlarken env değişkeni olarak veriyorum. (ör. BASIC_AUTH_USER ve BASIC_AUTH_PASS), htpasswd dosyası da başlangıçta bu değerlerden üretildi. 


## Önce bazı hazırlıklar yapmamız gerekiyor:

- AWS'de EC2 (t3.micro) makina ayağa kaldırıp içine Docker ve NGINX yükledim. Jenkins portu 8080 Jenkins'i hedef sunucuyla aynı makinaya kurdum.  O yüzden Jenkins image'ı orda build edip çalıştıracak. 

- Bir geliştirici kodu pushladığında, o kod nasıl otomatik şekilde sunucuda çalışır hale gelir bizim amacımız bu. Dockerfile siteyi container içinden sunar.

- Dockerfile: önce siteyi `NGINX` ile ayağa kaldırdım ve `localhost:8080`'de çalıştığını gördüm.

- Önce Dockerfile'ı yazdım. Sitemde sadece HTML, CSS ve JS dosyaları var. Basic Auth eklediğimde şifreyi soran server olacak o da siteyi sunan web sunucusu yani NGINX.

- Dockerfile: NGINX ile siteyi sunan bir Dockerfile yazdım önce

```dockerfile
#declare the base image
FROM nginx:alpine

#set a work directory
WORKDIR /usr/share/nginx/html

#copy files to work directory
COPY . .

#expose nginx port. Container'ın hangi port'u dinlediği.
EXPOSE 80

#command
CMD [ "nginx", "-g", "daemon off;" ]
```


- Sonra `docker info` komutuyla docker'ın çalışıp çalışmadığını kontrol edebilirsin. 

Ardından 
```bash
 docker build -t portfolio . 
 ```
 ```bash
  docker run -p 8080:80 portfolio. -p 8080:80
  ```
Artık build ettiğin image'ı eklediğin değişken ile çalıştırabilirsin:

```bash
docker run -e APP_ENV=prod -p 8080:80 portfolio
```

Bu komut container'ın içinde `APP_ENV` adında, değeri `prod` olan bir değişken oluşturur. Container'ın içindeki her program (shell script'ler, nginx'i başlatan süreç vb.) bu değeri görebilir.
Değişken çoksa `--env-file .env` ile hepsini bir dosyadan verebilirsin. Ek olarak `APP_ENV=dev` olarak da çalıştırabilirsin.

Her seferinde `curl -I localhost:8080` çıktısındaki header değişmeli.

```bash
docker run --rm nginx:alpine cat /etc/nginx/conf.d/default.conf
```

- `docker run`: `nginx:alpine` image'ından yeni bir container oluşturur.
- `cat /etc/nginx/conf.d/default.conf`: Container içindeki Nginx konfigürasyonunu terminale yazdırır.
- Komut tamamlanınca container durur.
- `--rm`: Duran container'ı otomatik siler.

## DEMO

```bash
docker info
```

### 1- nginx'in varsayılan ayarına bak

```bash
docker run --rm nginx:alpine cat /etc/nginx/conf.d/default.conf
```

### 2- repoya eklediğin nginx klasöründe default.conf.template dosyasını oluştur:

```nginx
server {
    listen 80;
    server_name localhost;

    # Her cevaba, APP_ENV değerini taşıyan bir header ekler
    add_header X-App-Env "${APP_ENV}";

    location / {
        root   /usr/share/nginx/html;
        index  index.html;
    }
}
```

### 3- Dockerfile'ı güncelle:

```dockerfile
#declare the base image
FROM nginx:alpine

#set a work directory
WORKDIR /usr/share/nginx/html

#copy files
COPY index.html style.css mediaqueries.css script.js ./
COPY assets ./assets

#Template'i nginx'in okuyacağı yere kopyala
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template


COPY --chmod=755 nginx/40-basic-auth.sh /docker-entrypoint.d/40-basic-auth.sh

#bu -e verilmezse kullanılacak değer, docker run -e ile verilen değer bunu ezer.
ENV APP_ENV=dev

#expose nginx port
EXPOSE 80

#command
CMD [ "nginx", "-g", "daemon off;" ]
```

### 4- Build et ve varsayılan değerle çalıştır

```bash
#Eski container hala çalışıyorsa önce onu sil
docker rm -f portfolio

docker build -t portfolio .

docker run -d --rm --name portfolio -p 8080:80 portfolio

curl -I localhost:8080
```

Çıktıda `X-App-Env: dev` satırını görmelisin.

Template'in nasıl doldurulduğunu görmek için:

```bash
docker logs portfolio

docker exec portfolio cat /etc/nginx/conf.d/default.conf
```

Loglarda: `20-envsubst-on-templates.sh` satırları görünmeli. Template'i bu script dolduruyor.

### 5- Değeri -e ile değiştir

```bash
docker stop portfolio

docker run -d --rm --name portfolio -p 8080:80 -e APP_ENV=prod portfolio

curl -I localhost:8080
```

Artık `X-App-Env: prod` görmelisin. Image'ı yeniden build etmedin.

### 6- Değişkenleri bir dosyadan ver

Repoda `.env` dosyası oluşturup içine: `APP_ENV=staging` ekle.

```bash
docker stop portfolio

docker run -d --rm --name portfolio -p 8080:80 --env-file .env portfolio

curl -I localhost:8080
```

Çıktıda `X-App-Env: staging` görmelisin.

Basic auth'ta da aynı yolu izleyeceksin. Sadece iki fark var:

- Değişkenler: `APP_ENV` yerine `BASIC_AUTH_USER` ve `BASIC_AUTH_PASS` olacak.
- Varsayılan değer: Şifre için Dockerfile'da `ENV` ile varsayılan değer tanımlama. `ENV` ile yazılan her şey image'ın içine gömülür, `docker history` ile görülebilir.
