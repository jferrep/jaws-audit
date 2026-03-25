# Instalación detallada / Detailed installation

> 🇪🇸 [Español](#español) | 🇬🇧 [English](#english)

---

## Español

### Prerrequisitos

```bash
# Verifica bash
bash --version  # necesitas 5+

# Instala curl si no lo tienes
sudo apt install -y curl

# Instala lynis (recomendado para auditoría completa)
sudo apt install -y lynis

# Instala rkhunter (recomendado para auditoría completa)
sudo apt install -y rkhunter
sudo rkhunter --update
sudo rkhunter --propupd
```

### Configurar Telegram

Necesitas un bot de Telegram y tu chat ID. Si no tienes uno:

1. Habla con [@BotFather](https://t.me/BotFather) en Telegram
2. Crea un bot con `/newbot` y guarda el token
3. Envía un mensaje a tu bot y obtén tu chat ID:

```bash
curl "https://api.telegram.org/bot<TU_TOKEN>/getUpdates"
```

Busca el campo `"id"` dentro de `"chat"` en la respuesta.

### Instalación paso a paso

```bash
# 1. Clona el repositorio
git clone https://github.com/jferrep/jaws-audit.git
cd jaws-audit

# 2. Copia los scripts al directorio de binarios del sistema
sudo cp audit.sh /usr/local/bin/jaws-audit.sh
sudo cp jaws-audit-check.sh /usr/local/bin/
sudo cp jaws-audit-full.sh /usr/local/bin/

# 3. Permisos correctos
sudo chown root:root /usr/local/bin/jaws-audit*.sh
sudo chmod 750 /usr/local/bin/jaws-audit*.sh

# 4. Crea el fichero de configuración
sudo cp jaws-audit.conf.example /etc/jaws-audit.conf
sudo chown root:root /etc/jaws-audit.conf
sudo chmod 600 /etc/jaws-audit.conf

# 5. Edita la configuración con tus credenciales
sudo nano /etc/jaws-audit.conf

# 6. Crea el directorio de logs
sudo mkdir -p /var/log/audits
sudo chmod 750 /var/log/audits
```

### Prueba de funcionamiento

```bash
# Prueba el script mensual
sudo /usr/local/bin/jaws-audit-check.sh

# Prueba la auditoría completa (tarda 3-5 minutos)
sudo /usr/local/bin/jaws-audit-full.sh

# Prueba la auditoría manual
sudo bash /usr/local/bin/jaws-audit.sh $(hostname)
```

Si todo funciona, deberías recibir mensajes en Telegram.

### Configurar cron

```bash
sudo crontab -e
```

Añade estas líneas:

```cron
# Auditoría ligera — día 1 de cada mes a las 8:00
0 8 1 * * /usr/local/bin/jaws-audit-check.sh

# Auditoría completa — día 1 de cada trimestre a las 9:00
0 9 1 1,4,7,10 * /usr/local/bin/jaws-audit-full.sh
```

### Verificar logs

```bash
# Ver auditorías guardadas
ls -lh /var/log/audits/

# Ver la última auditoría completa
ls -t /var/log/audits/audit_*.txt | head -1 | xargs less

# Comparar puntuaciones Lynis entre trimestres
grep "Hardening index" /var/log/audits/lynis_*.txt
```

---

## English

### Prerequisites

```bash
# Check bash version
bash --version  # requires 5+

# Install curl if missing
sudo apt install -y curl

# Install lynis (recommended for full audit)
sudo apt install -y lynis

# Install rkhunter (recommended for full audit)
sudo apt install -y rkhunter
sudo rkhunter --update
sudo rkhunter --propupd
```

### Setting up Telegram

You need a Telegram bot and your chat ID. If you don't have one:

1. Talk to [@BotFather](https://t.me/BotFather) on Telegram
2. Create a bot with `/newbot` and save the token
3. Send a message to your bot and get your chat ID:

```bash
curl "https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates"
```

Look for the `"id"` field inside `"chat"` in the response.

### Step-by-step installation

```bash
# 1. Clone the repository
git clone https://github.com/jferrep/jaws-audit.git
cd jaws-audit

# 2. Copy scripts to system binary directory
sudo cp audit.sh /usr/local/bin/jaws-audit.sh
sudo cp jaws-audit-check.sh /usr/local/bin/
sudo cp jaws-audit-full.sh /usr/local/bin/

# 3. Set correct permissions
sudo chown root:root /usr/local/bin/jaws-audit*.sh
sudo chmod 750 /usr/local/bin/jaws-audit*.sh

# 4. Create configuration file
sudo cp jaws-audit.conf.example /etc/jaws-audit.conf
sudo chown root:root /etc/jaws-audit.conf
sudo chmod 600 /etc/jaws-audit.conf

# 5. Edit configuration with your credentials
sudo nano /etc/jaws-audit.conf

# 6. Create log directory
sudo mkdir -p /var/log/audits
sudo chmod 750 /var/log/audits
```

### Testing

```bash
# Test monthly check script
sudo /usr/local/bin/jaws-audit-check.sh

# Test full audit (takes 3-5 minutes)
sudo /usr/local/bin/jaws-audit-full.sh

# Test manual audit
sudo bash /usr/local/bin/jaws-audit.sh $(hostname)
```

If everything works, you should receive Telegram messages.

### Setting up cron

```bash
sudo crontab -e
```

Add these lines:

```cron
# Monthly check — 1st day of each month at 8:00
0 8 1 * * /usr/local/bin/jaws-audit-check.sh

# Full audit — 1st day of each quarter at 9:00
0 9 1 1,4,7,10 * /usr/local/bin/jaws-audit-full.sh
```

### Checking logs

```bash
# List saved audits
ls -lh /var/log/audits/

# View latest full audit
ls -t /var/log/audits/audit_*.txt | head -1 | xargs less

# Compare Lynis scores across quarters
grep "Hardening index" /var/log/audits/lynis_*.txt
```
