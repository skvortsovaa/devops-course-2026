
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
