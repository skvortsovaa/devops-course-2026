
# Настройка сервера devops-vm

## 1. Сетевая конфигурация

- ОС: Ubuntu Server 24.04.
- Виртуализация: VirtualBox.
- NAT: 10.0.2.15.
- Host-only: 192.168.56.101.
- Домен: devops.local.
- SSH: порт 2222 через перенаправление NAT.

## 2. SSH

Подключение из WSL:

```bash
ssh -i ~/.ssh/id_ed25519_devops -p 2222 devops@127.0.0.1
```

Используется аутентификация по ключу Ed25519.

## 3. Межсетевой экран UFW

- Входящие соединения по умолчанию запрещены.
- Исходящие соединения разрешены.
- SSH: 2222/tcp, режим limit.
- HTTP: 80/tcp, allow.
- HTTPS: 443/tcp, allow.

Проверка:

```bash
sudo ufw status verbose
```

## 4. Nginx

Версия: Nginx 1.24.0.

Конфигурация сайта:
- `/etc/nginx/sites-available/devops-site`
- `/etc/nginx/sites-enabled/devops-site`

Каталог сайта: `/var/www/devops-site`.

Журналы:
- `/var/log/nginx/devops-site.access.log`
- `/var/log/nginx/devops-site.error.log`

Проверка:

```bash
sudo nginx -t
sudo systemctl status nginx
```

## 5. HTTPS

Используется самоподписанный сертификат для devops.local.

- Сертификат: `/etc/ssl/certs/devops.crt`.
- Закрытый ключ: `/etc/ssl/private/devops.key`.
- Поддерживаются TLS 1.2 и TLS 1.3.
- HTTP перенаправляется на HTTPS с кодом 301.

Проверка из WSL:

```bash
curl --cacert ~/devops.crt -I https://devops.local
```

## 6. Права доступа

- Каталог `/var/www/devops-site`: 755.
- HTML-файлы: 644.
- Владелец файлов: devops.
- Пользователь Nginx: www-data.

Пользователь www-data может читать страницы, но не изменять их.

Проверка:

```bash
find /var/www/devops-site -type f -perm -o+w
```

Команда не должна выводить файлов.

## 7. Автоматический деплой

Исходные файлы сайта находятся в `site/`.

Скрипт доставки: `scripts/deploy.sh`.

Пробный запуск:

```bash
bash scripts/deploy.sh --dry-run
```

Рабочий запуск:

```bash
bash scripts/deploy.sh
```

Скрипт использует rsync с параметрами `--delete` и `--chmod=D755,F644`, проверяет чистоту рабочего дерева Git и доступность сайта по HTTPS.

## 8. Проверка и аудит конфигурации

Необходимо контролировать:

1. Работу службы Nginx.
2. Корректность конфигурации Nginx.
3. Срок действия TLS-сертификата.
4. Отсутствие файлов сайта с правом записи для всех.
5. Защиту закрытого ключа TLS.

Проверки выполняются скриптом `scripts/audit.sh`.

## 9. Контейнеризация

### Установка Docker

На виртуальной машине Ubuntu 24.04 установлен Docker Engine из официального репозитория Docker и плагин Docker Compose.

Проверка установки: docker version, docker compose version, sudo systemctl status docker.

Пользователь devops входит в группу docker и выполняет команды Docker без sudo.

### Размещение приложения

Исходные файлы находятся в каталоге app/ репозитория.
На виртуальной машине приложение размещено в /home/devops/app/.

Доставка файлов выполняется через rsync с параметрами -avz --delete --exclude=.env.

### Переменные окружения

Шаблон переменных: app/.env.example.
Рабочий файл: /home/devops/app/.env.

Файл .env содержит параметры PostgreSQL и пароль, не отслеживается Git и имеет права доступа 600.

### Docker Compose

Конфигурация: app/docker-compose.yml.

Сервис app — Flask-приложение на Python 3.12 с Gunicorn.
Сервис db — PostgreSQL 16 Alpine.

Контейнеры используют внутреннюю сеть app_backend.
Приложение запускается после перехода PostgreSQL в состояние healthy.

Запуск: docker compose up -d --build.
Проверка: docker compose ps.
Остановка: docker compose down.

### Порты и постоянное хранилище

Порт приложения опубликован только на 127.0.0.1:5000.
Порт PostgreSQL 5432 наружу не опубликован.

Данные PostgreSQL хранятся в томе app_db_data.

Команда docker compose down сохраняет данные.
Команда docker compose down -v удаляет том вместе с данными.

### Обратный прокси Nginx

Nginx принимает HTTPS-запросы по адресу https://devops.local/app/ и перенаправляет их на http://127.0.0.1:5000/.

Конфигурация: /etc/nginx/sites-available/devops-site.

Проверка приложения:
curl --cacert ~/devops.crt https://devops.local/app/
curl --cacert ~/devops.crt https://devops.local/app/health

При остановке контейнера приложения Nginx возвращает 502 Bad Gateway.
