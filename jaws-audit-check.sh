#!/usr/bin/env bash
# =============================================================================
#  jaws-audit-check.sh — Auditoría mensual ligera
#  Ejecuta comprobaciones rápidas y notifica por Telegram
#  Cron: 0 8 1 * * /usr/local/bin/jaws-audit-check.sh
# =============================================================================

set -euo pipefail

CONFIG="/etc/jaws.conf"
LOG_DIR="/var/log/audits"
HOSTNAME=$(hostname)
DATE=$(date '+%Y-%m-%d %H:%M')
ISSUES=()
SUMMARY=""

# ─── Carga configuración ────────────────────────────────────────────────────
if [ ! -f "$CONFIG" ]; then
    echo "ERROR: No se encuentra $CONFIG" >&2
    exit 1
fi
source "$CONFIG"

# ─── Directorio de logs ─────────────────────────────────────────────────────
mkdir -p "$LOG_DIR"
chmod 750 "$LOG_DIR"

# ─── Función: enviar mensaje Telegram ───────────────────────────────────────
send_telegram() {
    local message="$1"
    if [ -n "${TELEGRAM_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
        curl -fsS "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "parse_mode=HTML" \
            --data-urlencode "text=${message}" > /dev/null 2>&1 || true
    fi
}

# ─── Comprobación 1: Reboot pendiente ───────────────────────────────────────
if [ -f /var/run/reboot-required ]; then
    ISSUES+=("⚠️ Reboot pendiente")
fi

# ─── Comprobación 2: Paquetes de seguridad sin instalar ─────────────────────
SEC_PKGS=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)
if [ "$SEC_PKGS" -gt 0 ]; then
    ISSUES+=("⚠️ ${SEC_PKGS} paquetes de seguridad sin instalar")
fi

# ─── Comprobación 3: Servicios caídos ───────────────────────────────────────
FAILED_SERVICES=$(systemctl list-units --type=service --state=failed --no-legend 2>/dev/null | wc -l)
if [ "$FAILED_SERVICES" -gt 0 ]; then
    FAILED_NAMES=$(systemctl list-units --type=service --state=failed --no-legend 2>/dev/null | awk '{print $1}' | tr '\n' ' ')
    ISSUES+=("❌ ${FAILED_SERVICES} servicios caídos: ${FAILED_NAMES}")
fi

# ─── Comprobación 4: Uso de disco > 80% ─────────────────────────────────────
while IFS= read -r line; do
    USAGE=$(echo "$line" | awk '{print $5}' | tr -d '%')
    MOUNT=$(echo "$line" | awk '{print $6}')
    if [ "$USAGE" -ge 80 ]; then
        ISSUES+=("💾 Disco ${MOUNT} al ${USAGE}%")
    fi
done < <(df -h | grep -v tmpfs | grep -v "Use%" | awk '{print $0}')

# ─── Comprobación 5: Intentos SSH fallidos (últimos 7 días) ─────────────────
SSH_FAILS=$(journalctl _SYSTEMD_UNIT=sshd.service --since "7 days ago" --no-pager 2>/dev/null \
    | grep -c "Failed password\|Invalid user" || true)
TOP_IP=$(journalctl _SYSTEMD_UNIT=sshd.service --since "7 days ago" --no-pager 2>/dev/null \
    | grep "Failed password\|Invalid user" \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
    | sort | uniq -c | sort -rn | head -1 || true)

# ─── Comprobación 6: fail2ban activo ────────────────────────────────────────
if ! systemctl is-active --quiet fail2ban; then
    ISSUES+=("❌ fail2ban no está activo")
fi

# ─── Comprobación 7: UFW activo ─────────────────────────────────────────────
if command -v ufw &>/dev/null; then
    UFW_STATUS=$(ufw status 2>/dev/null | head -1)
    if [[ "$UFW_STATUS" != *"active"* ]]; then
        ISSUES+=("❌ UFW no está activo")
    fi
fi

# ─── Genera el mensaje ───────────────────────────────────────────────────────
if [ ${#ISSUES[@]} -eq 0 ]; then
    STATUS_ICON="✅"
    STATUS_TEXT="Todo OK"
else
    STATUS_ICON="⚠️"
    STATUS_TEXT="${#ISSUES[@]} issue(s) encontrados"
fi

MESSAGE="<b>🔍 Auditoría mensual — ${HOSTNAME}</b>
📅 ${DATE}
${STATUS_ICON} <b>${STATUS_TEXT}</b>"

if [ ${#ISSUES[@]} -gt 0 ]; then
    MESSAGE+="

<b>Problemas detectados:</b>"
    for issue in "${ISSUES[@]}"; do
        MESSAGE+="
• ${issue}"
    done
fi

MESSAGE+="

<b>Resumen SSH (últimos 7 días):</b>
• Intentos fallidos: ${SSH_FAILS}"

if [ -n "$TOP_IP" ]; then
    MESSAGE+="
• IP más activa: ${TOP_IP}"
fi

# Baneadas por fail2ban
if command -v fail2ban-client &>/dev/null && systemctl is-active --quiet fail2ban; then
    BANNED=$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $NF}' || echo "0")
    MESSAGE+="
• IPs baneadas ahora: ${BANNED}"
fi

MESSAGE+="

<i>Próxima auditoría completa: ver cron trimestral</i>"

# ─── Guarda log y notifica ───────────────────────────────────────────────────
LOG_FILE="${LOG_DIR}/check_$(date +%Y%m%d).txt"
echo "$MESSAGE" | sed 's/<[^>]*>//g' > "$LOG_FILE"

send_telegram "$MESSAGE"

echo "Auditoría mensual completada. Issues: ${#ISSUES[@]}"
