# LSD-Tector 1.0

**Estación autónoma de monitoreo bioacústico para identificación de especies de aves mediante BirdNET-Pi en Raspberry Pi 4.**

Desarrollado en el Laboratorio de Sistemas Dinámicos (LSD), Facultad de Ciencias Exactas y Naturales, Universidad de Buenos Aires.

---

## Descripción

El LSD-Tector es un dispositivo de campo autónomo que graba audio en ventanas horarias de alta actividad biológica (amanecer y atardecer), identifica especies de aves mediante BirdNET-Pi, y envía los resultados a Google Drive. El sistema opera completamente sin intervención humana, gestionando su propio ciclo de encendido/apagado mediante un módulo RTC y alimentándose de un panel solar.

## Hardware requerido

- Raspberry Pi 4 Model B (4GB RAM)
- PiJuice HAT
- Batería LiPo 3.7V 10.000 mAh (modelo Akzytue 1160100, conector PH2.0)
- Panel solar 30W (Enertik Monocristalino) + buck converter a 9.5V
- Micrófono USB omnidireccional (Genius MIC-100U)
- Tarjeta microSD 32GB
- Caja estanca IP65 (Genrod 150×150×100mm)

---

## Instalación — paso a paso

### 1. Sistema operativo

Instalar **Raspberry Pi OS Full 64-bit** (Bookworm) en la microSD. Crear usuario `lsd` con contraseña `fourier1822`.

### 2. BirdNET-Pi

```bash
curl -s https://raw.githubusercontent.com/Nachtzuster/BirdNET-Pi/main/newinstaller.sh | bash
```

### 3. Dependencias Python

```bash
pip install astral --break-system-packages
```

### 4. PiJuice (API Python)

```bash
git clone https://github.com/PiSupply/PiJuice.git /home/lsd/BirdNET-Pi/PiJuice
cd /home/lsd/BirdNET-Pi/PiJuice/Software/Source
pip install . --break-system-packages
```

### 5. rclone (sincronización con Google Drive)

```bash
sudo apt install rclone
```

Autenticar rclone con Google Drive desde una PC con navegador:

```bash
# En la PC (Windows):
.\rclone.exe authorize "drive"
# Copiar el token generado

# En la RP:
rclone config
# Crear configuración "gdrive" → Google Drive → pegar token
```

### 6. hostapd y dnsmasq (para el hotspot de configuración)

```bash
sudo apt install hostapd dnsmasq --reinstall
sudo systemctl enable dnsmasq
```

Copiar el archivo de configuración del hotspot:

```bash
sudo cp systemd/hostapd.conf /etc/hostapd/hostapd.conf
```

### 7. Habilitar I2C para la PiJuice

```bash
sudo raspi-config
# Interface Options → I2C → Enable
```

### 8. Scripts del sistema

Copiar todos los scripts a `/home/lsd/`:

```bash
cp scripts/* /home/lsd/
cp python/* /home/lsd/
chmod +x /home/lsd/*.sh
```

Copiar archivos de configuración iniciales:

```bash
cp config/config_general.txt /home/lsd/
cp config/config_horarios.txt /home/lsd/
```

> **Importante:** editar `config_general.txt` con las coordenadas del lugar de instalación si no se va a usar el sistema de primer arranque (hotspot).

### 9. Configurar el perfil de batería en la PiJuice

```bash
python3 /home/lsd/configurar_bateria_pijuice.py
```

### 10. Configurar no_battery_turn_on en la PiJuice

```bash
python3 -c "
import sys
sys.path.append('/home/lsd/BirdNET-Pi/PiJuice/Software/Source')
from pijuice import PiJuice
pj = PiJuice(1, 0x14)
config = pj.config.GetPowerInputsConfig()['data']
config['no_battery_turn_on'] = True
pj.config.SetPowerInputsConfig(config)
print(pj.config.GetPowerInputsConfig())
"
```

### 11. Crontab

```bash
crontab -e
```

Agregar las siguientes líneas:

```
* * * * * /home/lsd/cierre_amanecer.sh
* * * * * /home/lsd/cierre_atardecer.sh
* * * * * /home/lsd/inicio_amanecer.sh
* * * * * /home/lsd/inicio_atardecer.sh
```

### 12. Servicios systemd

```bash
sudo cp systemd/sync-rtc.service /etc/systemd/system/
sudo cp systemd/hotspot.service /etc/systemd/system/
sudo systemctl enable sync-rtc.service
sudo systemctl enable hotspot.service
```

### 13. Primer arranque en campo

Al instalar el dispositivo en campo con `FIRST_START = TRUE` en `config_general.txt`:

1. Encender el dispositivo
2. Conectarse desde el celular a la red WiFi `BirdNET-Setup` (contraseña: `birdnet123`)
3. Abrir el navegador en `http://192.168.4.1:5000`
4. Seleccionar la red WiFi del lugar e ingresar la contraseña
5. El dispositivo se configura automáticamente y arranca el ciclo normal

---

## Estructura del repositorio

```
LSD-Tector/
├── README.md
├── scripts/
│   ├── cierre_amanecer.sh       — rutina de cierre de ventana amanecer
│   ├── cierre_atardecer.sh      — rutina de cierre de ventana atardecer
│   ├── inicio_amanecer.sh       — rutina de inicio de ventana amanecer
│   ├── inicio_atardecer.sh      — rutina de inicio de ventana atardecer
│   ├── hotspot.sh               — sistema de primer arranque y configuración WiFi
│   ├── auto_sync_horarios.sh    — sincronización automática de horarios
│   └── setup_wifi.sh            — configuración de red WiFi
├── python/
│   ├── portal_configuracion.py  — servidor web del portal de configuración
│   ├── calcular_horarios.py     — cálculo de horarios de amanecer/atardecer
│   ├── log_sistema.py           — sistema de log remoto
│   ├── set_wake_pijuice.py      — programación de alarma RTC PiJuice
│   ├── sync_pijuice_rtc.py      — sincronización del RTC PiJuice
│   └── configurar_bateria_pijuice.py — configuración del perfil de batería
├── config/
│   ├── config_horarios.txt      — horarios de ventanas de grabación
│   └── config_general.txt       — parámetros generales del dispositivo
└── systemd/
    ├── sync-rtc.service         — sincronización RTC al arranque
    ├── hotspot.service          — servicio de primer arranque
    └── hostapd.conf             — configuración del punto de acceso WiFi
```

---

## Flujo operacional

El ciclo diario del dispositivo es el siguiente:

1. El RTC de la PiJuice despierta la RP a la hora de inicio de ventana programada
2. El servicio `sync-rtc` sincroniza el reloj del sistema desde el RTC
3. Cron ejecuta `inicio_amanecer.sh` o `inicio_atardecer.sh` (2 minutos después del inicio)
4. Se verifica el nivel de batería — si es insuficiente, se cancela la ventana
5. BirdNET-Pi graba y detecta aves durante la ventana
6. Al finalizar la ventana, cron ejecuta `cierre_amanecer.sh` o `cierre_atardecer.sh`
7. Se sincronizan relojes, se suben detecciones a Google Drive, se actualiza el log
8. Se programa la alarma para la próxima ventana y la RP se apaga

---

## Parámetros configurables

### config_horarios.txt

| Parámetro | Descripción |
|---|---|
| `inicio_amanecer` / `fin_amanecer` | Horario de la ventana de amanecer (HH:MM) |
| `inicio_atardecer` / `fin_atardecer` | Horario de la ventana de atardecer (HH:MM) |
| `AUTO_SYNC` | ON/OFF — sincronización automática de horarios con astral |
| `duracion_amanecer_sync` | Duración de la ventana de amanecer en horas |
| `duracion_atardecer_sync` | Duración de la ventana de atardecer en horas |
| `offset_amanecer_sync` | Offset en minutos respecto al amanecer astronómico |
| `offset_atardecer_sync` | Offset en minutos respecto al atardecer astronómico |

### config_general.txt

| Parámetro | Descripción |
|---|---|
| `FIRST_START` | TRUE/FALSE — activa el modo hotspot de configuración inicial |
| `LAT` / `LON` | Coordenadas GPS del lugar de instalación |
| `SSID` / `PASSWORD` | Credenciales de la red WiFi (se actualizan automáticamente via hotspot) |
| `CONSUMO_WH` | Consumo estimado por ventana en Wh (usado para umbral de supervivencia) |
| `CAPACIDAD_MAH` | Capacidad de la batería en mAh |
| `VOLTAJE_BATERIA` | Voltaje nominal de la batería en V |
| `MARGEN_SEGURIDAD` | Factor de seguridad para el cálculo del umbral de batería |
