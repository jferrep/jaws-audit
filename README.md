# jaws-audit

> 🇪🇸 [Español](#español) | 🇬🇧 [English](#english)

---

## Español

### ¿Qué es esto?

`jaws-audit` es un conjunto de scripts bash para auditar servidores Ubuntu 24.04. Recoge información sobre seguridad, rendimiento y configuración en un único fichero de texto, y opcionalmente notifica por Telegram cuando detecta problemas.

Desarrollado y usado en producción en servidores Hetzner VPS con Nginx, PHP-FPM, MySQL, WireGuard y Docker.

### Scripts incluidos

| Script | Descripción | Frecuencia recomendada |
|--------|-------------|------------------------|
| `audit.sh` | Auditoría completa: sistema, usuarios, puertos, servicios, Nginx, PHP, WireGuard, Docker, logs | Manual / trimestral |
| `jaws-audit-check.sh` | Comprobación ligera: reboot, paquetes de seguridad, servicios caídos, disco, SSH | Mensual (cron) |
| `jaws-audit-full.sh` | Auditoría completa automatizada con Lynis y rkhunter + notificación Telegram | Trimestral (cron) |

### Requisitos

- Ubuntu 24.04 (compatible con otras versiones Debian/Ubuntu)
- `bash` 5+
- `curl` (para notificaciones Telegram)
- `lynis` — opcional, para `jaws-audit-full.sh`
- `rkhunter` — opcional, para `jaws-audit-full.sh`

### Instalación rápida

```bash
# Clona el repo
git clone https://github.com/jferrep/jaws-audit.git
cd jaws-audit

# Copia los scripts
sudo cp audit.sh /usr/local/bin/jaws-audit.sh
sudo cp jaws-audit-check.sh /usr/local/bin/
sudo cp jaws-audit-full.sh /usr/local/bin/
sudo chmod 750 /usr/local/bin/jaws-audit*.sh

# Copia y edita la configuración
sudo cp jaws-audit.conf.example /etc/jaws-audit.conf
sudo chmod 600 /etc/jaws-audit.conf
sudo nano /etc/jaws-audit.conf  # añade tu token y chat ID de Telegram
```

Instrucciones detalladas en [docs/INSTALL.md](docs/INSTALL.md).

### Uso

```bash
# Auditoría manual con etiqueta
sudo bash /usr/local/bin/jaws-audit.sh vps-web

# El resultado se guarda en:
# audit_vps-web_YYYYMMDD_HHMMSS.txt
```

### Automatización con cron

```bash
sudo crontab -e
```

```cron
# Comprobación mensual — día 1 de cada mes a las 8:00
0 8 1 * * /usr/local/bin/jaws-audit-check.sh

# Auditoría completa — día 1 de cada trimestre a las 9:00
0 9 1 1,4,7,10 * /usr/local/bin/jaws-audit-full.sh
```

### Artículos relacionados

Esta herramienta se desarrolló y documenta en una serie de artículos en [jaumeferre.net](https://jaumeferre.net):

1. [Auditando mis servidores: por qué, cómo y con qué](https://jaumeferre.net/blog/auditoria-servidores-el-script/)
2. [Leyendo los logs de una auditoría: qué es ruido y qué es real](https://jaumeferre.net/blog/auditoria-servidores-interpretando-resultados/)
3. [De 68 a 76 puntos: hardening real de un VPS Ubuntu 24.04](https://jaumeferre.net/blog/auditoria-servidores-hardening/)
4. [Bonus: automatizando la auditoría con cron y Telegram](https://jaumeferre.net/blog/auditoria-servidores-automatica-cron-telegram/)

### Licencia

MIT — úsalo, modifícalo, compártelo.

---

## English

### What is this?

`jaws-audit` is a set of bash scripts for auditing Ubuntu 24.04 servers. It collects security, performance, and configuration information into a single text file, and optionally sends Telegram notifications when issues are detected.

Developed and used in production on Hetzner VPS servers running Nginx, PHP-FPM, MySQL, WireGuard, and Docker.

### Included scripts

| Script | Description | Recommended frequency |
|--------|-------------|----------------------|
| `audit.sh` | Full audit: system, users, ports, services, Nginx, PHP, WireGuard, Docker, logs | Manual / quarterly |
| `jaws-audit-check.sh` | Lightweight check: pending reboot, security packages, failed services, disk usage, SSH | Monthly (cron) |
| `jaws-audit-full.sh` | Automated full audit with Lynis and rkhunter + Telegram notification | Quarterly (cron) |

### Requirements

- Ubuntu 24.04 (compatible with other Debian/Ubuntu versions)
- `bash` 5+
- `curl` (for Telegram notifications)
- `lynis` — optional, required for `jaws-audit-full.sh`
- `rkhunter` — optional, required for `jaws-audit-full.sh`

### Quick install

```bash
# Clone the repo
git clone https://github.com/jferrep/jaws-audit.git
cd jaws-audit

# Copy scripts
sudo cp audit.sh /usr/local/bin/jaws-audit.sh
sudo cp jaws-audit-check.sh /usr/local/bin/
sudo cp jaws-audit-full.sh /usr/local/bin/
sudo chmod 750 /usr/local/bin/jaws-audit*.sh

# Copy and edit configuration
sudo cp jaws-audit.conf.example /etc/jaws-audit.conf
sudo chmod 600 /etc/jaws-audit.conf
sudo nano /etc/jaws-audit.conf  # add your Telegram token and chat ID
```

Detailed instructions in [docs/INSTALL.md](docs/INSTALL.md).

### Usage

```bash
# Manual audit with label
sudo bash /usr/local/bin/jaws-audit.sh vps-web

# Output saved to:
# audit_vps-web_YYYYMMDD_HHMMSS.txt
```

### Cron automation

```bash
sudo crontab -e
```

```cron
# Monthly check — 1st day of each month at 8:00
0 8 1 * * /usr/local/bin/jaws-audit-check.sh

# Full audit — 1st day of each quarter at 9:00
0 9 1 1,4,7,10 * /usr/local/bin/jaws-audit-full.sh
```

### Related articles

This tool was developed and documented in a blog series at [jaumeferre.net](https://jaumeferre.net):

1. [Auditing my servers: why, how and with what](https://jaumeferre.net/blog/auditoria-servidores-el-script/) *(Spanish)*
2. [Reading audit logs: what's noise and what's real](https://jaumeferre.net/blog/auditoria-servidores-interpretando-resultados/) *(Spanish)*
3. [From 68 to 76: real hardening of an Ubuntu 24.04 VPS](https://jaumeferre.net/blog/auditoria-servidores-hardening/) *(Spanish)*
4. [Bonus: automating audits with cron and Telegram](https://jaumeferre.net/blog/auditoria-servidores-automatica-cron-telegram/) *(Spanish)*

### License

MIT — use it, modify it, share it.
