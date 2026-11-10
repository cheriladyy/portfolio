# JENKINS

 Control + Command + Boşluk sembol penceresi açılacak

- Jenkins EC2'da çalışacak ve buraya deploy edecek. Ya burası biraz sıkıntılı belki demoda sorarsın.
- Ek olarak portlar da çoğaldı NGINX `80` portunda çalışıyor ama Jenkins `8080` portunda çalışacak ve `8081`'e deploy edecek. 

- `http://<EC2-IP>:8081` ile erişeceğiz sonra da.

## 1. Makinayı hazırla

### 1.1 Swap ekle

 t3.micro'da 1 GB RAM var. Jenkins'in bellek yetmediği için kapanmaması için 2 GB swap ekle:
```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
free -h
```
### 1.2 Docker'ı kur: 
```bash
sudo apt install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker ubuntu #ubuntu kullanıcısının sudo yazmadan docker komutunu kullanabilmesini sağlar
groups #mevcut grupları gösterir
```

### 1.3 Portları aç:
```
Custom TCP - 8080 - My IP  
Custom TCP - 8081 - 0.0.0.0/0
```

## 2. Siteyi Docker'la manuel çalıştır

### 2.1. önce repoyu git pull
```bash
cd ~/portfolio
git checkout main
git pull
ls
```
### 2.2. Image'ı build et

```bash
docker build -t portfolio .
```
bu adımda hata aldın:

 Step 6/9 : COPY --chmod=755 nginx/40-basic-auth.sh /docker-entrypoint.d/40-basic-auth.sh
    the --chmod option requires BuildKit. Refer to https://docs.docker.com/go/buildkit/ to learn how to build images with BuildKit enabled

Çözüm buildx kurmak:

```bash
sudo apt install -y docker-buildx
docker buildx version
```

### 2.3. Tekrar build et 

```bash
docker build -t portfolio .
docker images portfolio
```

### 2.4 .env dosyasını oluştur

Bu dosya repoda yok, çünkü .gitignore'da. Sunucuda elle oluşturman gerekiyor:
```bash
vim ~/portfolio/.env

#içine de şunları ekle
APP_ENV=prod
BASIC_AUTH_USER=<username>
BASIC_AUTH_PASS=<password>

#sonra dosyayı sadece senin okuyabileceğin şekilde kilitle:
chmod 600 ~/portfolio/.env
```
### 2.5 Container'ı çalıştır:

```bash
docker run -d --name portfolio --restart unless-stopped -p 8081:80 --env-file ~/portfolio/.env portfolio
```

- -p 8081:80: Sunucunun 8081 portunu container'ın 80 portuna bağlar. 80 portu nginx'te olduğu için bilgisayarındaki gibi 8080 değil, 8081 kullanıyoruz. 8080'i de Jenkins kullanacak.
- --restart unless-stopped: Container çökerse ya da sunucu yeniden başlarsa Docker container'ı otomatik başlatır. Sen elle durdurduysan başlatmaz. 
- --rm yok çünkü burada container kalıcı olmalı.

### 2.6 Test et:
Sunucunun içinden:

```bash
docker ps
curl -s -o /dev/null -w "%{http_code}\n" -u gizem:<sifre> localhost:8081   # 200
```

Kendi bilgisayarından tarayıcıda:
```
http://<EC2-IP>:8081 adresini aç
```

```
docker logs image-name
```

`Artık aynı sunucuda iki ayrı site çalışıyor:`
- http://<EC2-IP>  doğrudan sunucuya kurulan nginx.
- http://<EC2-IP>:8081  Docker container'ı. Basic auth'lu.

## 3. Jenkins'i kur

Jenkins'i Docker container olarak değil doğrudan sunucuda kurdum. 

### 3.1 Java'yı kur

```bash
sudo apt update
sudo apt install -y fontconfig openjdk-21-jre
java -version
```

### 3.2 Start by downloading the Jenkins repository signing key and storing it in the system keyrings directory:

```bash
sudo mkdir -p /etc/apt/keyrings

#This command retrieves the Jenkins GPG key and saves it in /etc/apt/keyrings, which is the recommended location for repository keys on modern Ubuntu systems.
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

#Next, add the Jenkins Debian repository to your APT sources:
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

#After adding the repository, update the local package index so apt can recognize the new source
sudo apt update
sudo apt install jenkins
```

The signed-by option instructs apt to verify packages from this repository using the specific GPG key you downloaded earlier. This limits trust to only this repository and avoids using a system-wide key.


### 3.3 Start Jenkins:

Now that Jenkins is installed, start it using systemctl:

```bash
sudo systemctl start jenkins.service

#Since systemctl does not display status output, we’ll use the status command to verify that Jenkins started successfully:

sudo systemctl status jenkins
```

If everything went well, the beginning of the status output shows that the service is active and configured to start at boot:
```bash
Output● jenkins.service - Jenkins Continuous Integration Server
     Loaded: loaded (/usr/lib/systemd/system/jenkins.service; enabled; preset: enabled)
     Active: active (running) since Thu 2026-02-05 06:20:00 UTC; 29s ago
   Main PID: 2292 (java)
      Tasks: 50 (limit: 4655)
     Memory: 718.8M (peak: 719.6M)
        CPU: 27.378s
     CGroup: /system.slice/jenkins.service
             └─2292 /usr/bin/java -Djava.awt.headless=true -jar /usr/share/java/jenkins.war

```

### 3.4 Jenkins'e Docker izni ver. 
Pipeline docker build ve docker run komutlarını jenkins kullanıcısı olarak çalıştıracak. Bu yüzden onu da docker grubuna ekle:

```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
sudo -u jenkins docker ps
```

## 4. Jenkins'i konfigure et:

### 4.1 Tarayıcıda aç: http://<EC2-IP>:8080

"Unlock Jenkins" ekranı gelecek. İstenen şifreyi sunucudan al:
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### 4.2 Pluginler:
 `Install suggested plugins` seç. Bu listede Git ve Pipeline plugin'leri de var, ihtiyacın olanların hepsi bunlar.

### 4.3 Admin kullanıcısı oluştur:
 Kullanıcı adı ve şifre belirle.

### 4.4 Instance Configuration

 Jenkins URL olarak http://<EC2-IP>:8080/ önerilecek, olduğu gibi bırak. 

```markdown
Burda Jenkins timeout verdi. Sorun security group. 8081 portuna gerekli IP'leri ekle. Şirket IP'si kendin IP'n vs.


curl -4 -s --max-time 10 ifconfig.me
bu komutu çalıştırarak bilgisayarının IP'sini bul. Whatsmyip senin değil netscope'un ipsi
```

Jenkins sayfasıa açılacak ama Admin password isteyecek. Şurdan kontrol edeceksin:

```bash
#EC2'da: 

sudo cat /var/lib/jenkins/secrets/initialAdminPassword

#Çıkan 32 karakterlik kodu kopyalayıp Jenkins sayfasındaki Administrator password alanına yapıştır, Continue'ya bas.
```

### 5. Kurulum tamam. Disk sorunu çözülecek şimdi. 

Plugin kurulumu sırasında disk dolmuş. Plugin'ler ```/var/lib/jenkins``` klasörüne iniyor ve disk zaten dolmak üzereydi. 

Kurulum hata verirdi. 
```bash
df -h /  
lsblk 
```
çıktılarına bak. 

```Manage Jenkins → Nodes``` sayfasında Built-In Node'da sıkıntı var.


### 5.1 AWS'de diski büyüt

- ```EC2 → Instances → makineni seç → Storage sekmesi → Volume ID → Actions → Modify volume Size: 20 → Modify → onayla```

AWS diski büyüttü ama işletim sistemi bunu kendiliğinden kullanmaz. Önce partition sonra dosya sistemini büyütmen gerekiyor.
```bash
sudo growpart /dev/nvme0n1 1
sudo resize2fs /dev/nvme0n1p1
df -h /
```
>Nodes sayfasındayenileme butonuna bas değerler güncellenecek.

Bunu yapınca disk sorunu çözüldü ama node hala offline, çünkü Free Temp Space değişmemiş.
Çözüm: Jenkins'in geçici klasörünü diske taşı

Jenkins'e /tmp yerine kendi veri klasöründeki bir klasörü kullanmasını söyleyeceğiz. Bu klasör diskte duruyor ve 12 GB'lık alandan yararlanabiliyor.

### 5.2 Klasörü oluştur:

```bash
sudo mkdir -p /var/lib/jenkins/tmp
sudo chown jenkins:jenkins /var/lib/jenkins/tmp
```

### 5.3 Jenkins servisinin ayarını değiştir:
```bash
sudo systemctl edit jenkins
```
Boş alana şunu yaz:
```json
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djava.io.tmpdir=/var/lib/jenkins/tmp"
```

### 5.4 Jenkins'i yeniden başlat ve ayarın geçtiğini kontrol et:

```bash
sudo systemctl restart jenkins

ps aux | grep -o 'java.io.tmpdir=[^ ]*'
#Çıktıda java.io.tmpdir=/var/lib/jenkins/tmp görmelisin.
```


## 6. Basic auth şifresini Jenkins'e kaydet

Sunucuda .env dosyasında tuttuğun kullanıcı adını ve şifreyi Jenkins da bilmeli. Ama Jenkinsfile'a yazmamalısın, çünkü repo herkese açık. Jenkins'in Credentials bölümü bu iş için var: şifreyi şifrelenmiş olarak saklar, pipeline sırasında kullanır ve loglarda maskeler.

1. Manage Jenkins → Credentials → System → Global credentials (unrestricted) → Add Credentials.
2. Alanları doldur:
   - Kind: Username with password
   - Username: gizem (ya da .env'de ne kullandıysan)
   - Password: Site şifren
   - ID: portfolio-basic-auth. Jenkinsfile bu ID ile şifreye ulaşacak.
   - Description: Basic auth for portfolio site
3. Create.


>YALNIZ BURDA ÖNEMLİ BİR ŞEY VAR BİRAZDAN OLUŞTURACAĞIN JENKINSFILE'DA BU ID'Yİ KULLANMAN GEREKİYOR FYI.

## 7. Önce Jenkinsfile oluşturuyoruz. 

Not: Jenkinsfile Groovy dilinde yazılır.

```groovy
pipeline {
    agent any #Run this on any available Jenkins agent

    options {
        skipDefaultCheckout()
    }

    environment {
        IMAGE_NAME     = 'portfolio'
        CONTAINER_NAME = 'portfolio'
        HOST_PORT      = '8081'
    }

    stages {
        stage('Clone') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                sh 'docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} -t ${IMAGE_NAME}:latest .'
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'portfolio-basic-auth',
                    usernameVariable: 'BASIC_AUTH_USER',
                    passwordVariable: 'BASIC_AUTH_PASS'
                )]) {
                    sh '''
                        docker rm -f ${CONTAINER_NAME} || true
                        docker run -d \
                          --name ${CONTAINER_NAME} \
                          --restart unless-stopped \
                          -p ${HOST_PORT}:80 \
                          -e APP_ENV=prod \
                          -e BASIC_AUTH_USER \
                          -e BASIC_AUTH_PASS \
                          ${IMAGE_NAME}:${BUILD_NUMBER}
                    '''
                }
            }
        }
    }
}
```


## 8. Pipeline'ı merge ettikten sonra:

1. Ana sayfada New Item.
2. Enter an item name: portfolio-pipeline. Tür olarak Pipeline seç → OK.
3. Ayar sayfasında aşağı inip Pipeline bölümünü bul:
   - Definition: Pipeline script from SCM
   - SCM: Git
   - Repository URL: https://github.com/cheriladyy/portfolio.git. Jenkins herkese açık repoyu HTTPS ile clone'layabiliyor, bu yüzden SSH anahtarına gerek yok.
   - Credentials: - none -. Repo herkese açık.
   - Branch Specifier: */main
   - Script Path: Jenkinsfile
4. Save.
5. Job sayfasında sol menüden Build Now'a bas.

Build'i izlemek için: Sol alttaki Build History bölümünde #1 görünecek. Ona tıkla → Console Output. Komutların çıktısını canlı olarak izleyebilirsin.

Bundan sonra `http://<EC2-IP>:8081` adresine git. 
bir de makinada `docker ps` çalıştır container çalışıyor.

Buraya kadar manuel trigger'ı tamamlamış oldun. Şimdi pull trigger ekleyeceğiz. 

 Github Actions: Add github pull trigger

Yapılacaklar:
1. Jenkins API token'ı ve EC2'deki tetikleme script'i 
2. GitHub'ın AWS'ye şifresiz bağlanabilmesi için güven ilişkisi (OIDC) ve IAM rolü
3. GitHub Actions workflow dosyası
4. Uçtan uca test

## 9. Jenkins Tarafını Hazırla

>Jenkins'i sunucunun içinden tetikleyen bir script yazılacak:
#### 9.1 Jenkins'te API token oluştur

1. Jenkins'te sağ üstteki kullanıcı adına tıkla → Security. Bazı sürümlerde bu sayfanın adı Configure.
2. API Token bölümünde Add new Token → isim olarak ssm-trigger yaz → Generate.
3. Çıkan token'ı hemen kopyala, kayboluyor.

>API token neden gerekli: curl ile Jenkins'e "build başlat" demek için Jenkins'e giriş yapmış olman gerekiyor. API token, kendi şifren yerine kullanılan ve istediğin zaman iptal edebileceğin ayrı bir anahtar. 

### 9.2 Token'ı EC2'da sadece root'un okuyabileceği bir dosyaya kaydet:

```bash
sudo install -m 600 -o root -g root /dev/null /etc/jenkins-trigger.env
sudo vim /etc/jenkins-trigger.env

#İçine şunu yaz:
JENKINS_USER=<jenkins-admin-kullanici-adin>
JENKINS_TOKEN=<az-once-kopyaladigin-token>
```
- install -m 600 -o root -g root: Dosyayı boş olarak oluşturur, sahibini root yapar ve izinlerini 600 olarak ayarlar. 600 sadece sahibin (root) okuyup yazabileceği anlamına gelir.
- Neden root: SSM'in çalıştırdığı komutlar sunucuda root olarak çalışır. Bu yüzden dosyaya root'un erişmesi yeterli.

### 9.3  Tetikleme script'ini oluştur:
```bash
sudo vim /usr/local/bin/trigger-jenkins.sh
```

İçine şunu yaz:
```bash
#!/bin/sh
set -eu

. /etc/jenkins-trigger.env

curl -fsS -X POST \
  -u "$JENKINS_USER:$JENKINS_TOKEN" \
  http://localhost:8080/job/portfolio-pipeline/build

echo "Jenkins build triggered"
Sonra script'i sadece root'un çalıştırabileceği şekilde ayarla:
sudo chmod 700 /usr/local/bin/trigger-jenkins.sh
```

- set -eu:
  - -e: Herhangi bir komut hata verirse script durur.
  - -u: Tanımlanmamış bir değişken kullanılırsa script durur. 
- . /etc/jenkins-trigger.env: Dosyadaki değişkenleri script'e yükler. Baştaki nokta, source komutunun kısa hali.
- curl -fsS -X POST:
  - -X POST: Jenkins build başlatmak için POST isteği bekliyor.
  - -f: Jenkins hata kodu dönerse (401, 404 gibi) curl de hata verir. Böylece set -e script'i durdurur ve GitHub Actions'ta bu adım kırmızı görünür.
  - -sS: İlerleme çubuğunu gizler, ama hata mesajlarını gösterir.
- /job/portfolio-pipeline/build: Jenkins'te o job'ı tetikleyen adres. Job'ının adı farklıysa burayı değiştir.

### 9.4 Test et:
```bash
sudo /usr/local/bin/trigger-jenkins.sh
```
- Ekranda Jenkins build triggered görmelisin.
- Jenkins'te portfolio-pipeline job'ında yeni bir build başlayacak.

Hata alırsan:
- 401: Kullanıcı adı ya da token yanlış.
- 404: Job adı yanlış. Jenkins'teki job adı ile script'teki adı karşılaştır.

Jenkins tarafı hazır. 

## 10 AWS'de GitHub için izinleri hazırla

Dört parça kuracağız:
-  SSM document: Sadece trigger-jenkins.sh script'ini çalıştıracak.
-  OIDC provider: AWS'nin GitHub'a güvenmesi.
-  IAM rolü: GitHub'ın üstleneceği kimlik. Sadece senin repondaki main branch'i kullanabilecek.
-  İzin politikası: Bu rol sadece (a)'daki komutu, sadece senin EC2'nde çalıştırabilecek.

### 10.1 SSM Document

AWS'nin hazır AWS-RunShellScript document'ı sunucuda her komutu çalıştırabilir. GitHub'a bunu verirsek, GitHub hesabına erişen biri sunucunda root olarak her şeyi yapabilir. Bunun yerine sadece bizim script'i çalıştıran özel bir document oluşturacağız.

1. Systems Manager → Documents → Create document → Command or Session.
2. Name: TriggerJenkins.
3. Document type: Command document. Content: JSON.
4. İçeriği şununla değiştir:

```json
{
  "schemaVersion": "2.2",
  "description": "Trigger the portfolio-pipeline Jenkins job",
  "mainSteps": [
    {
      "action": "aws:runShellScript",
      "name": "triggerJenkins",
      "inputs": {
        "runCommand": ["/usr/local/bin/trigger-jenkins.sh"]
      }
    }
  ]
}
```

5. Create document.

Test et:
1. Systems Manager → Run Command → Run command → TriggerJenkins document'ını seç.
2. Targets: "Choose instances manually" → kendi EC2'ni seç → Run.
3. Durum Success olmalı ve Jenkins'te yeni bir build başlamalı.

### 10.2 OIDC provider

Bu adım sayesinde GitHub'a AWS access key vermeyeceğiz. Her workflow çalışmasında GitHub token üretir, AWS de onu doğrulayıp birkaç dakikalık geçici yetki verir. Kalıcı bir anahtar değil.

1. IAM → Identity providers → Add provider.
2. Provider type: OpenID Connect.
3. Provider URL: https://token.actions.githubusercontent.com
4. Audience: sts.amazonaws.com
5. Add provider.

### 10.3 IAM role

1. IAM → Roles → Create role.
2. Trusted entity type: Web identity.
3. Alanları doldur:
   - Identity provider: token.actions.githubusercontent.com
   - Audience: sts.amazonaws.com
   - GitHub organization: cheriladyy
   - GitHub repository: portfolio
   - GitHub branch: main
4. Next → izin ekleme adımını şimdilik boş geç → Next.
5. Role name: github-actions-trigger-jenkins → Create role.

Güven ilişkisini kontrol et: Rol -> Trust relationships sekmesi. Condition bölümünde şu satır olmalı:
"token.actions.githubusercontent.com:sub": "repo:cheriladyy/portfolio:ref:refs/heads/main"
Bununla birlikte rolü başka repolar ya da branchler kullanamaz.

### 10.4 IAM Policy

1. Rolün sayfasında Permissions → Add permissions → Create inline policy → JSON.
2. İçeriği şununla değiştir:
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ssm:SendCommand",
      "Resource": [
        "arn:aws:ssm:<REGION>:<ACCOUNT_ID>:document/TriggerJenkins",
        "arn:aws:ec2:<REGION>:<ACCOUNT_ID>:instance/<INSTANCE_ID>"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "ssm:GetCommandInvocation",
      "Resource": "*"
    }
  ]
}
3. Policy name: send-trigger-jenkins-command → Create policy.

İzinlerin anlamı:
- ssm:SendCommand: Komut gönderme izni. İki kaynağın ikisi de gerekli:
  - Document: Hangi komutun gönderilebileceği. Sadece TriggerJenkins.
  - Instance: Komutun hangi sunucuya gönderilebileceği. Sadece senin EC2'n.
- ssm:GetCommandInvocation: Gönderilen komutun sonucunu okuma izni. Workflow, Jenkins'in gerçekten tetiklenip tetiklenmediğini bununla öğrenecek. Bu işlem kaynak bazında kısıtlanamadığı için * kullanılıyor. Sadece okuma izni olduğu için risk yok.

Role ARN'sini kullanacağız.

Rolün sayfasının üstünde ARN yazıyor:
arn:aws:iam::<ACCOUNT_ID>:role/github-actions-trigger-jenkins
Bunu bir sonraki adımda GitHub'a vereceğiz.

Buraları yaptın ama Actions hata verecek onun için de CloudTrail'e bakacaksın:

1. AWS Console'da CloudTrail → Event history.
2. Lookup attributes: Event name seç, değer olarak AssumeRoleWithWebIdentity yaz.
3. Listede başarısız denemelerini göreceksin. En son olanına tıkla.
4. Event record bölümündeki JSON'da şu satırı bul:
"userName": "repo:cheriladyy/portfolio:ref:refs/heads/..."
   Bu değer, GitHub'ın gönderdiği sub değerinin kendisi.

sub değeri beklediğimizden farklı. GitHub'ın gerçekte gönderdiği değer şu:
>repo:cheriladyy@158853286/portfolio@1449502429:ref:refs/heads/main

Trust policy'de ise şu yazıyor:

>repo:cheriladyy/portfolio:ref:refs/heads/main

O yüzden çözüm: Trust policy'yi güncelle

IAM → Roles → github-actions-trigger-jenkins → Trust relationships → Edit trust policy. İçeriği şununla değiştir:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::044173279858:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
                    "token.actions.githubusercontent.com:sub": "repo:cheriladyy@158853286/portfolio@1449502429:ref:refs/heads/main"
                }
            }
        }
    ]
}
```

## 11. GitHub Actions

### 11.1 GitHub'a rol ve sunucu bilgisini ver

GitHub'da repo sayfası → Settings → Secrets and variables → Actions → New repository secret. İki secret ekle:
```
AWS_ROLE_ARN 
EC2_INSTANCE_ID
```

### 11.2 Workflow'u yaz

>.github/workflows/trigger-jenkins.yml: 

```yaml
name: Trigger Jenkins

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

jobs:
  trigger-jenkins:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: eu-west-1

      - name: Trigger Jenkins via SSM
        env:
          INSTANCE_ID: ${{ secrets.EC2_INSTANCE_ID }}
        run: |
          COMMAND_ID=$(aws ssm send-command \
            --document-name TriggerJenkins \
            --instance-ids "$INSTANCE_ID" \
            --query Command.CommandId \
            --output text)
          echo "SSM command ID: $COMMAND_ID"

          aws ssm wait command-executed \
            --command-id "$COMMAND_ID" \
            --instance-id "$INSTANCE_ID"

          aws ssm get-command-invocation \
            --command-id "$COMMAND_ID" \
            --instance-id "$INSTANCE_ID" \
            --query StandardOutputContent \
            --output text
```
>workflow_dispatch:  Workflow'u elle de tetikleyebilirsin
>permissions: id-token: OIDC üretir.         
>contents: read              │ Workflow'a repoyu okumak dışında hiçbir izin vermez. Varsayılan izinleri kısıtlamak iyi bir alışkanlık
>send-command                │ SSM'den TriggerJenkins document'ını senin EC2'nde çalıştırmasını ister. Komut ID'sini döndürür
>wait command-executed       │ Komut bitene kadar bekler 
>get-command-invocation      │ Script'in çıktısını workflow loguna yazar. Jenkins build triggered satırını burada göreceksin 

### 11.3 Commit'le, push et, merge et

```bash
git add .github/workflows/trigger-jenkins.yml
git commit -m "Trigger Jenkins via SSM on push to main"
git push -u origin github-actions-trigger
```
Sonra PR açıp main'e merge et.

Workflow çalıştı. Task tamamlandı.
