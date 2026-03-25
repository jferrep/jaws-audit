#!/usr/bin/env bash
# =============================================================================
#  audit.sh — Auditoría de servidor Linux (Ubuntu 24.04)
#  Uso: bash audit.sh [etiqueta]
#  Ejemplo: bash audit.sh vps-web
# =============================================================================

LABEL="${1:-$(hostname)}"
OUT="audit_${LABEL}_$(date +%Y%m%d_%H%M%S).txt"
SEPARATOR="════════════════════════════════════════════════════════════════"

run() {
    local title="$1"; shift
    echo ""
    echo "▶ ${title}"
    echo "────────────────────────────────────────────────────────────────"
    "$@" 2>&1 || true
}

exec > >(tee "$OUT") 2>&1

echo "$SEPARATOR"
echo "  AUDITORÍA: ${LABEL}  —  $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "$SEPARATOR"

# ─── SISTEMA ──────────────────────────────────────────────────────────────────
echo ""
echo "████  SISTEMA  ████"

run "Kernel y hostname"        uname -a
run "Uptime y carga"           uptime
run "CPU"                      lscpu | grep -E "Model name|CPU\(s\)|Thread|Core"
run "Memoria RAM"              free -h
run "Uso de disco"             df -hT | grep -v tmpfs
run "Inodos críticos"          df -ih | awk '$5+0 >= 70 || NR==1'
run "Temperatura CPU"          cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null \
                                 | awk '{printf "%.1f°C\n", $1/1000}' \
                               || echo "(no disponible)"

# ─── ACTUALIZACIONES ──────────────────────────────────────────────────────────
echo ""
echo "████  ACTUALIZACIONES  ████"

run "Paquetes actualizables (seguridad)"  \
    apt list --upgradable 2>/dev/null | grep -i security

run "Todos los paquetes actualizables"   \
    apt list --upgradable 2>/dev/null | grep -v "^Listing"

run "Estado unattended-upgrades"         \
    systemctl is-enabled unattended-upgrades 2>/dev/null

run "Última ejecución apt"               \
    stat /var/lib/apt/periodic/update-success-stamp 2>/dev/null \
    || echo "(no existe stamp)"

run "Reboot pendiente"                   \
    ls /var/run/reboot-required 2>/dev/null && cat /var/run/reboot-required-pkgs \
    || echo "No se requiere reboot"

# ─── USUARIOS Y ACCESOS ───────────────────────────────────────────────────────
echo ""
echo "████  USUARIOS Y ACCESOS  ████"

run "Usuarios con shell válida"          \
    grep -v -E "(nologin|false|sync)" /etc/passwd \
    | awk -F: '{print $1, $3, $6, $7}'

run "Usuarios con UID 0 (root)"          \
    awk -F: '($3==0){print}' /etc/passwd

run "Sudoers y grupos privilegiados"     \
    getent group sudo wheel | cat

run "Últimos 20 logins"                  \
    last -n 20 -a

run "Últimos 20 intentos fallidos"       \
    lastb -n 20 -a 2>/dev/null \
    || journalctl _SYSTEMD_UNIT=ssh.service --no-pager -n 40 \
       | grep -i "failed\|invalid"

run "Resumen auth.log (últimas 24h)"     \
    journalctl --since "24 hours ago" _SYSTEMD_UNIT=ssh.service --no-pager \
    | grep -Eo "(Invalid user|Failed password|Accepted|publickey|Disconnected)" \
    | sort | uniq -c | sort -rn

run "IPs con más intentos fallidos (auth.log)"  \
    journalctl --since "7 days ago" _SYSTEMD_UNIT=ssh.service --no-pager \
    | grep "Invalid user\|Failed password" \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
    | sort | uniq -c | sort -rn | head -20

run "Claves SSH autorizadas (todos los usuarios)"  \
    find /root /home -name "authorized_keys" 2>/dev/null \
    | while read f; do echo "==> $f"; cat "$f"; done

run "Sesiones activas"                   \
    who -a

# ─── SEGURIDAD ────────────────────────────────────────────────────────────────
echo ""
echo "████  SEGURIDAD  ████"

run "Estado fail2ban"                    \
    systemctl is-active fail2ban

run "Jails activas fail2ban"             \
    fail2ban-client status 2>/dev/null \
    || echo "(fail2ban no activo)"

run "IPs baneadas por jail (sshd)"       \
    fail2ban-client status sshd 2>/dev/null \
    || echo "(jail sshd no activa)"

run "Estado UFW"                         \
    ufw status verbose 2>/dev/null

run "Puertos abiertos (ss)"              \
    ss -tlnpu

run "Puertos escuchando en 0.0.0.0 / :: (atención)"  \
    ss -tlnpu | grep -E "0\.0\.0\.0|::"

run "Ficheros SUID fuera de /usr /bin /sbin"  \
    find / -xdev -perm -4000 -type f 2>/dev/null \
    | grep -v -E "^/(usr|bin|sbin|snap)"

run "Ficheros SGID fuera de /usr /bin /sbin"  \
    find / -xdev -perm -2000 -type f 2>/dev/null \
    | grep -v -E "^/(usr|bin|sbin|snap)" | head -20

run "World-writable dirs (excl. /tmp /proc /sys)"  \
    find / -xdev -type d -perm -0002 2>/dev/null \
    | grep -v -E "^/(tmp|proc|sys|run|dev)"

run "Crontabs activos"                   \
    for u in $(cut -d: -f1 /etc/passwd); do
        crontab -l -u "$u" 2>/dev/null && echo "(usuario: $u)"
    done
    ls /etc/cron* /var/spool/cron/crontabs/ 2>/dev/null

run "Configuración SSH (/etc/ssh/sshd_config)"  \
    grep -v -E "^#|^$" /etc/ssh/sshd_config | sort

run "Módulos PAM inusuales"              \
    grep -r "pam_exec\|pam_script" /etc/pam.d/ 2>/dev/null \
    || echo "Ninguno"

# ─── SERVICIOS ────────────────────────────────────────────────────────────────
echo ""
echo "████  SERVICIOS  ████"

run "Servicios activos"                  \
    systemctl list-units --type=service --state=running --no-legend \
    | sort

run "Servicios fallidos"                 \
    systemctl list-units --type=service --state=failed --no-legend

run "Servicios habilitados en boot"      \
    systemctl list-unit-files --type=service --state=enabled --no-legend \
    | sort

run "Timers systemd activos"             \
    systemctl list-timers --no-legend

# ─── PROCESOS Y RENDIMIENTO ───────────────────────────────────────────────────
echo ""
echo "████  PROCESOS Y RENDIMIENTO  ████"

run "Top 15 por CPU"                     \
    ps aux --sort=-%cpu | head -16

run "Top 15 por memoria"                 \
    ps aux --sort=-%mem | head -16

run "Memoria virtual / swap"             \
    vmstat -s | head -20

run "I/O de disco"                       \
    iostat -x 1 3 2>/dev/null \
    || echo "(iostat no instalado: apt install sysstat)"

run "Conexiones de red establecidas"     \
    ss -s

run "Conexiones ESTABLISHED por IP"      \
    ss -tn state established \
    | awk '{print $5}' | cut -d: -f1 \
    | sort | uniq -c | sort -rn | head -20

# ─── NGINX ────────────────────────────────────────────────────────────────────
if command -v nginx &>/dev/null; then
    echo ""
    echo "████  NGINX  ████"

    run "Versión y módulos compilados"   nginx -V

    run "Test de configuración"          nginx -t

    run "Parámetros clave"               \
        nginx -T 2>/dev/null \
        | grep -E "worker_processes|worker_connections|worker_rlimit|keepalive_timeout|keepalive_requests|client_max_body|gzip|ssl_protocols|ssl_ciphers|server_tokens|add_header|open_file_cache" \
        | grep -v "^#"

    run "Virtual hosts habilitados"      \
        ls -la /etc/nginx/sites-enabled/ 2>/dev/null \
        || ls -la /etc/nginx/conf.d/ 2>/dev/null

    run "Logs de error recientes (últimas 50 líneas)"  \
        tail -n 50 /var/log/nginx/error.log 2>/dev/null

    run "Top IPs en access.log (últimas 10k líneas)"  \
        tail -n 10000 /var/log/nginx/access.log 2>/dev/null \
        | awk '{print $1}' | sort | uniq -c | sort -rn | head -20

    run "Códigos de respuesta (últimas 10k líneas)"   \
        tail -n 10000 /var/log/nginx/access.log 2>/dev/null \
        | awk '{print $9}' | sort | uniq -c | sort -rn
fi

# ─── PHP-FPM ──────────────────────────────────────────────────────────────────
if systemctl list-units --type=service --state=running 2>/dev/null | grep -q php; then
    echo ""
    echo "████  PHP-FPM  ████"

    run "Versión PHP"                    php --version

    run "Servicios PHP-FPM activos"      \
        systemctl list-units --type=service --state=running \
        | grep php

    PHP_POOLS=$(find /etc/php -name "*.conf" -path "*/fpm/pool.d/*" 2>/dev/null)
    if [ -n "$PHP_POOLS" ]; then
        run "Configuración de pools PHP-FPM"  \
            grep -h -E "pm\.|listen|^user|^group" $PHP_POOLS
    fi
fi

# ─── WIREGUARD ────────────────────────────────────────────────────────────────
if command -v wg &>/dev/null; then
    echo ""
    echo "████  WIREGUARD  ████"

    run "Estado de interfaces WireGuard" wg show

    run "Rutas via WireGuard"            \
        ip route | grep -E "wg|10\.100\."

    run "Interfaces de red"              \
        ip -brief addr show

    run "IP forwarding activo"           \
        sysctl net.ipv4.ip_forward net.ipv6.conf.all.forwarding 2>/dev/null
fi

# ─── DOCKER (si existe) ───────────────────────────────────────────────────────
if command -v docker &>/dev/null; then
    echo ""
    echo "████  DOCKER  ████"

    run "Versión Docker"                 docker version --format '{{.Server.Version}}'

    run "Contenedores activos"           docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

    run "Contenedores parados"           docker ps -a --filter status=exited \
                                           --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"

    run "Imágenes (sin usar)"            docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

    run "Volúmenes"                      docker volume ls

    run "Uso de disco Docker"            docker system df
fi

# ─── LOGS Y EVENTOS ───────────────────────────────────────────────────────────
echo ""
echo "████  LOGS Y EVENTOS  ████"

run "Errores de kernel recientes"        \
    dmesg --level=err,crit,emerg --time-format=reltime 2>/dev/null | tail -30

run "Errores journald (últimas 24h)"     \
    journalctl -p err --since "24 hours ago" --no-pager | tail -40

run "Uso de espacio en /var/log"         \
    du -sh /var/log/* 2>/dev/null | sort -rh | head -20

# ─── FIN ──────────────────────────────────────────────────────────────────────
echo ""
echo "$SEPARATOR"
echo "  FIN — Output guardado en: $OUT"
echo "$SEPARATOR"
