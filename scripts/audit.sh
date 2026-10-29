
#!/usr/bin/env bash

set -u

SITE_DIR="/var/www/devops-site"
CERT="/etc/ssl/certs/devops.crt"
KEY="/etc/ssl/private/devops.key"

ERRORS=0

check() {
    local number="$1"
    local description="$2"
    shift 2

    if "$@"; then
        echo "[OK] [$number] $description"
    else
        echo "[FAIL] [$number] $description"
        ERRORS=$((ERRORS + 1))
    fi
}

check_nginx_service() {
    systemctl is-active --quiet nginx
}

check_nginx_config() {
    sudo -n nginx -t >/dev/null 2>&1
}

check_certificate() {
    openssl x509 -in "$CERT" -noout -checkend 2592000 >/dev/null 2>&1
}

check_site_permissions() {
    [[ -d "$SITE_DIR" ]] || return 1

    local unsafe_files
    unsafe_files=$(find "$SITE_DIR" -type f -perm -o+w -print -quit) || return 1

    [[ -z "$unsafe_files" ]]
}

check_private_key() {
    local permissions
    permissions=$(sudo -n stat -c '%a' "$KEY" 2>/dev/null) || return 1

    [[ "$permissions" == "600" ]]
}

echo "=== Аудит конфигурации devops-vm ==="

check 4 "Служба Nginx активна" check_nginx_service
check 5 "Конфигурация Nginx корректна" check_nginx_config
check 6 "Сертификат действителен не менее 30 дней" check_certificate
check 7 "Нет файлов сайта с правом записи для всех" check_site_permissions
check 8 "Закрытый ключ TLS имеет права 600" check_private_key

echo "==================================="

if (( ERRORS > 0 )); then
    echo "Аудит завершён: обнаружено ошибок — $ERRORS"
    exit 1
fi

echo "Аудит завершён успешно"
exit 0
