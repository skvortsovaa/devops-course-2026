#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]

set -euo pipefail

REMOTE="devops@127.0.0.1"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
SSH_KEY="${HOME}/.ssh/id_ed25519_devops"
SSH_PORT="2222"

DRY_RUN=false

if [[ $# -gt 1 ]]; then
    echo "Ошибка: допустим только параметр --dry-run" >&2
    exit 1
fi

if [[ $# -eq 1 ]]; then
    if [[ "$1" != "--dry-run" ]]; then
        echo "Ошибка: неизвестный параметр $1" >&2
        exit 1
    fi
    DRY_RUN=true
fi

REPO_ROOT="$(git -C "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" rev-parse --show-toplevel)"
LOCAL_DIR="${REPO_ROOT}/site/"
COMMIT="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"

if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
    echo "Ошибка: отсутствует site/index.html" >&2
    exit 1
fi

if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "Ошибка: в репозитории есть незакоммиченные изменения" >&2
    exit 1
fi

if [[ ! -r "$SSH_KEY" ]]; then
    echo "Ошибка: SSH-ключ недоступен: $SSH_KEY" >&2
    exit 1
fi

if [[ ! -r "$CA_CERT" ]]; then
    echo "Ошибка: сертификат недоступен: $CA_CERT" >&2
    exit 1
fi

SSH_CMD="ssh -i ${SSH_KEY} -p ${SSH_PORT} -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes"

RSYNC_ARGS=(
    -avz
    --delete
    --chmod=D755,F644
    -e "$SSH_CMD"
)

if [[ "$DRY_RUN" == true ]]; then
    RSYNC_ARGS+=(--dry-run)
    echo "Пробный запуск: изменения на сервере не выполняются"
fi

rsync "${RSYNC_ARGS[@]}" \
    "$LOCAL_DIR" \
    "${REMOTE}:${REMOTE_DIR}/"

if [[ "$DRY_RUN" == true ]]; then
    echo "Пробный запуск завершён успешно. Коммит: $COMMIT"
    exit 0
fi

if ! curl --silent --show-error --fail \
    --cacert "$CA_CERT" \
    --connect-timeout 5 \
    --max-time 15 \
    --output /dev/null \
    "$SITE_URL"; then
    echo "Ошибка: сайт недоступен после деплоя" >&2
    exit 1
fi

echo "Деплой выполнен успешно. Коммит: $COMMIT"
exit 0
