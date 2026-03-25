#!/usr/bin/env bash
# =============================================================================
#  jaws-audit-full.sh — Auditoría trimestral completa
#  Ejecuta audit.sh completo + Lynis y notifica por Telegram
#  Cron: 0 9 1 1,4,7,10 * /usr/local/bin/jaws-audit-full.sh
# =============================================================================

set -euo pipefail

CONFIG="/etc/jaws.conf"
LOG_DIR="/var/log/audits"
AUDIT_SCRIPT="/usr/local/bin/jaws-audit.sh"
HOSTNAME=$(hostname)
DATE=$(date '+%Y-%m-%d %H:%M')

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

# ─── Notifica inicio ────────────────────────────────────────────────────────
send_telegram "🔍 <b>Auditoría trimestral iniciada</b>
📅 ${DATE}
🖥️ Servidor: ${HOSTNAME}
⏳ Esto puede tardar unos minutos..."

# ─── Ejecuta audit.sh completo ──────────────────────────────────────────────
AUDIT_OUT="${LOG_DIR}/audit_${HOSTNAME}_$(date +%Y%m%d).txt"

if [ -f "$AUDIT_SCRIPT" ]; then
    bash "$AUDIT_SCRIPT" "$HOSTNAME" > "$AUDIT_OUT" 2>&1 || true
    AUDIT_SIZE=$(du -sh "$AUDIT_OUT" | cut -f1)
else
    echo "AVISO: $AUDIT_SCRIPT no encontrado" > "$AUDIT_OUT"
    AUDIT_SIZE="0"
fi

# ─── Ejecuta Lynis ──────────────────────────────────────────────────────────
LYNIS_SCORE=""
LYNIS_WARNINGS=""
LYNIS_SUGGESTIONS=""

if command -v lynis &>/dev/null; then
    LYNIS_OUT="${LOG_DIR}/lynis_${HOSTNAME}_$(date +%Y%m%d).txt"
    lynis audit system --quiet 2>/dev/null > "$LYNIS_OUT" || true

    LYNIS_SCORE=$(grep "Hardening index" "$LYNIS_OUT" | grep -oE '[0-9]+' | head -1 || echo "N/A")
    LYNIS_WARNINGS=$(grep "^  Warnings" "$LYNIS_OUT" | grep -oE '[0-9]+' | head -1 || echo "N/A")
    LYNIS_SUGGESTIONS=$(grep "^  Suggestions" "$LYNIS_OUT" | grep -oE '[0-9]+' | head -1 || echo "N/A")
else
    LYNIS_SCORE="Lynis no instalado"
fi

# ─── Comprobaciones rápidas ─────────────────────────────────────────────────
ISSUES=()

[ -f /var/run/reboot-required ] && ISSUES+=("⚠️ Reboot pendiente")

SEC_PKGS=$(apt list --upgradable 2>/dev/null | grep -ic security || true)
[ "$SEC_PKGS" -gt 0 ] && ISSUES+=("⚠️ ${SEC_PKGS} paquetes de seguridad pendientes")

FAILED=$(systemctl list-units --type=service --state=failed --no-legend 2>/dev/null | wc -l)
[ "$FAILED" -gt 0 ] && ISSUES+=("❌ ${FAILED} servicios caídos")

DISK_WARN=$(df -h | grep -v tmpfs | awk 'NR>1 {gsub(/%/,"",$5); if($5>=80) print $6" ("$5"%)"}' || true)
[ -n "$DISK_WARN" ] && ISSUES+=("💾 Disco al límite: ${DISK_WARN}")

! systemctl is-active --quiet fail2ban 2>/dev/null && ISSUES+=("❌ fail2ban inactivo")

SSH_FAILS=$(journalctl _SYSTEMD_UNIT=sshd.service --since "30 days ago" --no-pager 2>/dev/null \
    | grep -c "Failed password\|Invalid user" || true)

# ─── rkhunter ───────────────────────────────────────────────────────────────
RKHUNTER_RESULT=""
if command -v rkhunter &>/dev/null; then
    rkhunter --update --quiet 2>/dev/null || true
    RKHUNTER_WARNINGS=$(rkhunter --check --skip-keypress --rwo 2>/dev/null | wc -l || true)
    if [ "$RKHUNTER_WARNINGS" -gt 0 ]; then
        RKHUNTER_RESULT="⚠️ ${RKHUNTER_WARNINGS} warnings"
        ISSUES+=("⚠️ rkhunter: ${RKHUNTER_WARNINGS} warnings")
    else
        RKHUNTER_RESULT="✅ Limpio"
    fi
else
    RKHUNTER_RESULT="No instalado"
fi

# ─── Construye mensaje Telegram ─────────────────────────────────────────────
if [ ${#ISSUES[@]} -eq 0 ]; then
    STATUS="✅ Sin problemas críticos"
else
    STATUS="⚠️ ${#ISSUES[@]} issue(s) encontrados"
fi

MESSAGE="<b>📊 Auditoría trimestral completa — ${HOSTNAME}</b>
📅 ${DATE}

<b>Lynis:</b>
• Hardening index: <b>${LYNIS_SCORE}/100</b>
• Warnings: ${LYNIS_WARNINGS}
• Suggestions: ${LYNIS_SUGGESTIONS}

<b>rkhunter:</b> ${RKHUNTER_RESULT}

<b>SSH (últimos 30 días):</b>
• Intentos fallidos: ${SSH_FAILS}

<b>Estado general:</b> ${STATUS}"

if [ ${#ISSUES[@]} -gt 0 ]; then
    MESSAGE+="

<b>Issues detectados:</b>"
    for issue in "${ISSUES[@]}"; do
        MESSAGE+="
• ${issue}"
    done
fi

MESSAGE+="

<b>Ficheros guardados:</b>
• Auditoría: ${AUDIT_OUT} (${AUDIT_SIZE})
• Lynis: ${LYNIS_OUT:-No generado}"

# ─── Limpia logs antiguos (mantiene últimos 4 trimestres) ───────────────────
find "$LOG_DIR" -name "audit_*.txt" -mtime +400 -delete 2>/dev/null || true
find "$LOG_DIR" -name "lynis_*.txt" -mtime +400 -delete 2>/dev/null || true
find "$LOG_DIR" -name "check_*.txt" -mtime +35 -delete 2>/dev/null || true

# ─── Notifica ───────────────────────────────────────────────────────────────
send_telegram "$MESSAGE"

echo "Auditoría trimestral completada."
echo "Lynis score: ${LYNIS_SCORE}"
echo "Issues: ${#ISSUES[@]}"
