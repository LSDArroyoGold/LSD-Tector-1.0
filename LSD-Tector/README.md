# LSD-Tector 1.0

**Estación autónoma de monitoreo bioacústico para identificación de especies de aves mediante BirdNET-Pi en Raspberry Pi 4.**

Desarrollado en el Laboratorio de Sistemas Dinámicos (LSD), Facultad de Ciencias Exactas y Naturales, Universidad de Buenos Aires.

---

## Hardware requerido

- Raspberry Pi 4 Model B (4GB RAM)
- PiJuice HAT
- Batería LiPo 3.7V 10.000 mAh (modelo Akzytue 1160100, conector PH2.0)
- Panel solar 30W (Enertik Monocristalino) + buck converter configurado a 9.5V
- Micrófono USB omnidireccional (Genius MIC-100U)
- Tarjeta microSD 32GB
- Caja estanca IP65 (Genrod 150×150×100mm)

---

## Instalación — paso a paso

### 1. Sistema operativo

Instalar **Raspberry Pi OS Full 64-bit** (Bookworm) en la microSD usando Raspberry Pi Imager. Crear usuario `lsd` con contraseña `fourier1822` durante el proceso de flasheo (en la sección de configuración avanzada del Imager).

### 2. BirdNET-Pi

Desde la terminal de la RP:

```bash
curl -s https://raw.githubusercontent.com/Nachtzuster/BirdNET-Pi/main/newinstaller.sh | bash
```

La instalación toma varios minutos. Una vez finalizada, BirdNET-Pi quedará corriendo y accesible desde el navegador en `http://[IP_de_la_RP]`.

### 3. Dependencias Python

```bash
pip install astral --break-system-packages
```

### 4. PiJuice — API Python

El paquete oficial de PiJuice no está disponible en los repositorios de Raspberry OS. Instalarlo directamente desde el repositorio de GitHub, dentro del directorio de BirdNET-Pi para mantener todo organizado:

```bash
git clone https://github.com/PiSupply/PiJuice.git /home/lsd/BirdNET-Pi/PiJuice
cd /home/lsd/BirdNET-Pi/PiJuice/Software/Source
pip install . --break-system-packages
```

Verificar que la PiJuice es detectada en el bus I2C hardware (dirección 0x14):

```bash
sudo i2cdetect -y 1
```

Verificar que la API Python funciona:

```bash
python3 -c "
import sys
sys.path.append('/home/lsd/BirdNET-Pi/PiJuice/Software/Source')
from pijuice import PiJuice
pj = PiJuice(1, 0x14)
print(pj.status.GetStatus())
print(pj.status.GetChargeLevel())
"
```

### 5. Habilitar I2C

```bash
sudo raspi-config
```

Navegar a **Interface Options → I2C → Enable**. Confirmar y salir. Reiniciar:

```bash
sudo reboot
```

### 6. rclone — sincronización con Google Drive

```bash
sudo apt install rclone
```

La autenticación con Google Drive requiere un navegador. Como BirdNET-Pi ocupa el navegador de la RP, la autenticación se realiza desde una PC intermediaria con Windows:

**En la PC con Windows:**
1. Descargar rclone desde `https://rclone.org/downloads/` (versión Windows 64-bit)
2. Descomprimir el zip y abrir PowerShell en esa carpeta
3. Ejecutar:
```
.\rclone.exe authorize "drive"
```
4. El navegador se abrirá automáticamente. Iniciar sesión con la cuenta de Google deseada
5. Copiar el token JSON completo que aparece en PowerShell (desde `{` hasta `}`)

**En la RP:**
```bash
rclone config
```
Seguir estos pasos en el asistente interactivo:
- `n` → nueva configuración
- Nombre: `gdrive`
- Seleccionar Google Drive de la lista (buscar el número correspondiente)
- `client_id` y `client_secret`: dejar vacíos (Enter)
- Scope: opción `1` (acceso completo)
- Siguientes campos: dejar vacíos (Enter)
- Configuración avanzada: `n`
- Autenticación desde este dispositivo: `n` (porque usamos la PC)
- Pegar el token obtenido desde la PC
- Shared drive: `n`
- Confirmar: `y`
- Salir: `q`

Verificar que la conexión funciona:

```bash
rclone lsd gdrive:
```

### 7. hostapd y dnsmasq — para el hotspot de configuración inicial

```bash
sudo apt install hostapd dnsmasq --reinstall
sudo systemctl enable dnsmasq
sudo systemctl start dnsmasq
```

### 8. Scripts del sistema

Clonar este repositorio en la RP o copiar los archivos manualmente. Luego copiar todo a `/home/lsd/`:

```bash
cp scripts/* /home/lsd/
cp python/* /home/lsd/
chmod +x /home/lsd/*.sh
```

Copiar los archivos de configuración iniciales:

```bash
cp config/config_general.txt /home/lsd/
cp config/config_horarios.txt /home/lsd/
```

> **Nota:** Los archivos de configuración en `config/` contienen valores por defecto. Editarlos según las necesidades de la instalación antes de copiarlos, o editarlos directamente en `/home/lsd/` después de copiarlos.

Copiar el archivo de configuración del hotspot:

```bash
sudo cp systemd/hostapd.conf /etc/hostapd/hostapd.conf
```

### 9. Configurar el perfil de batería en la PiJuice

Este paso le indica a la PiJuice las características de la batería conectada para que el fuel gauge y el gestor de carga funcionen correctamente:

```bash
python3 /home/lsd/configurar_bateria_pijuice.py
```

Verificar que el perfil quedó aplicado — debe mostrar `chargeCurrent: 2500` y `capacity: 10000`:

```bash
python3 -c "
import sys
sys.path.append('/home/lsd/BirdNET-Pi/PiJuice/Software/Source')
from pijuice import PiJuice
pj = PiJuice(1, 0x14)
print(pj.config.GetBatteryProfile())
"
```

### 10. Configurar comportamiento de encendido de la PiJuice

Por defecto, la PiJuice enciende la RP automáticamente al detectar alimentación externa. Para que el sistema solo se encienda mediante la alarma programada del RTC, deshabilitar este comportamiento:

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

Verificar que `no_battery_turn_on` aparece como `True` en la salida.

### 11. Servicio de sincronización del RTC al arranque

Instalar el servicio que sincroniza el reloj del sistema con el RTC de la PiJuice cada vez que la RP arranca:

```bash
sudo cp systemd/sync-rtc.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable sync-rtc.service
sudo systemctl start sync-rtc.service
```

Verificar que el servicio está habilitado:

```bash
sudo systemctl status sync-rtc.service
```

### 12. Servicio de hotspot para primer arranque

Instalar el servicio que activa el modo hotspot de configuración WiFi cuando `FIRST_START = TRUE`:

```bash
sudo cp systemd/hotspot.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable hotspot.service
```

### 13. Crontab

Abrir el crontab del usuario `lsd` (importante: no usar sudo, para que las tareas corran como el usuario lsd):

```bash
crontab -e
```

La primera vez pregunta qué editor usar — seleccionar `nano` (opción 1). Agregar las siguientes líneas al final del archivo:

```
* * * * * /home/lsd/cierre_amanecer.sh
* * * * * /home/lsd/cierre_atardecer.sh
* * * * * /home/lsd/inicio_amanecer.sh
* * * * * /home/lsd/inicio_atardecer.sh
```

Guardar con **Ctrl+O**, Enter, **Ctrl+X**. Verificar que quedaron registradas:

```bash
crontab -l
```

### 14. Google Drive — crear carpeta de destino

Crear la carpeta de destino en Google Drive donde se almacenarán las detecciones y los archivos de configuración:

```bash
rclone mkdir "gdrive:Laboratorio 6"
rclone mkdir "gdrive:Laboratorio 6/BirdNET_Detecciones"
```

Subir los archivos de configuración iniciales a Drive:

```bash
rclone copy /home/lsd/config_horarios.txt "gdrive:Laboratorio 6/"
rclone copy /home/lsd/config_general.txt "gdrive:Laboratorio 6/"
```

### 15. Primer arranque en campo

Al instalar el dispositivo en un lugar nuevo, asegurarse de que `FIRST_START = TRUE` en `/home/lsd/config_general.txt`. Al encender el dispositivo:

1. Esperar aproximadamente 30 segundos a que el sistema arranque
2. Desde el celular, buscar y conectarse a la red WiFi **BirdNET-Setup** (contraseña: `birdnet123`)
3. Abrir el navegador y navegar a `http://192.168.4.1:5000`
4. Seleccionar la red WiFi del lugar de instalación e ingresar la contraseña
5. El dispositivo se conecta a la red, obtiene sus coordenadas GPS automáticamente, calcula los horarios de amanecer y atardecer, programa la próxima alarma y se apaga
6. A partir de ese momento opera de forma completamente autónoma

---

## Estructura del repositorio

```
LSD-Tector/
├── README.md
├── scripts/
│   ├── cierre_amanecer.sh         — ejecutado por cron al fin de la ventana de amanecer:
│   │                                sincroniza relojes, sube detecciones a Drive, loguea FIN,
│   │                                programa alarma para inicio_atardecer y apaga la RP
│   ├── cierre_atardecer.sh        — ídem para la ventana de atardecer; programa alarma
│   │                                para inicio_amanecer del día siguiente
│   ├── inicio_amanecer.sh         — ejecutado por cron 2 minutos después de inicio_amanecer:
│   │                                verifica nivel de batería, loguea INICIO o cancela ventana
│   ├── inicio_atardecer.sh        — ídem para la ventana de atardecer
│   ├── hotspot.sh                 — ejecutado por systemd al arranque: si FIRST_START=TRUE,
│   │                                levanta el hotspot WiFi de configuración inicial
│   ├── auto_sync_horarios.sh      — verifica AUTO_SYNC y ejecuta calcular_horarios.py si está ON
│   └── setup_wifi.sh              — agrega una red WiFi al sistema si no está guardada
├── python/
│   ├── portal_configuracion.py    — servidor HTTP en puerto 5000 para la configuración WiFi
│   │                                inicial; escanea redes disponibles y gestiona la conexión
│   ├── calcular_horarios.py       — calcula horarios de amanecer/atardecer usando astral,
│   │                                actualiza config_horarios.txt local y lo sube a Drive
│   ├── log_sistema.py             — escribe entradas en log_sistema.txt con timestamp,
│   │                                nivel de batería y tipo de evento (INICIO/FIN/CANCELADA)
│   ├── set_wake_pijuice.py        — programa la alarma del RTC de la PiJuice para despertar
│   │                                la RP a la hora indicada como argumento (HH:MM)
│   ├── sync_pijuice_rtc.py        — sincroniza el RTC de la PiJuice con la hora del sistema
│   └── configurar_bateria_pijuice.py — configura el perfil de batería custom en la PiJuice
├── config/
│   ├── config_horarios.txt        — horarios de ventanas y parámetros de AUTO_SYNC
│   └── config_general.txt         — parámetros generales: coordenadas, batería, WiFi, FIRST_START
└── systemd/
    ├── sync-rtc.service           — sincroniza reloj del sistema desde RTC al arranque
    ├── hotspot.service            — lanza hotspot.sh al arranque del sistema
    ├── reset_wifi.service         — (pendiente) reconfiguración WiFi via botón físico
    └── hostapd.conf               — configuración del punto de acceso WiFi (SSID y contraseña)
```

---

## Flujo operacional diario

```
[RTC PiJuice despierta la RP]
        ↓ inicio_amanecer o inicio_atardecer
[sync-rtc.service sincroniza reloj del sistema desde RTC]
        ↓
[cron ejecuta inicio_amanecer.sh o inicio_atardecer.sh a inicio+2min]
        ↓
[Calcula umbral de batería desde config_general.txt]
        ↓
[Consulta nivel de batería via API PiJuice]
        ↓
  ¿Batería < umbral?
  SÍ → log CANCELADA → WiFi ON → sube log a Drive → WiFi OFF
     → programa alarma próxima ventana → poweroff
  NO → log INICIO → WiFi ON → sube log → WiFi OFF → BirdNET graba
        ↓ fin_amanecer o fin_atardecer
[cron ejecuta cierre_amanecer.sh o cierre_atardecer.sh]
        ↓
[WiFi ON → sync NTP → sync RTC PiJuice]
        ↓
[Borra sonogramas .png y carpeta Charts]
        ↓
[Sube .mp3 a Drive]
        ↓
[Cuenta detecciones de la ventana → log FIN]
        ↓
[AUTO_SYNC=ON → calcular_horarios.py actualiza config_horarios.txt → sube a Drive]
        ↓
[Descarga config_horarios.txt actualizado desde Drive]
        ↓
[Sube log_sistema.txt a Drive → WiFi OFF]
        ↓
[Programa alarma RTC PiJuice para próxima ventana]
        ↓
[SetPowerOff(30) → sudo poweroff]
```

---

## Parámetros configurables

### config_horarios.txt

| Parámetro | Descripción |
|---|---|
| `inicio_amanecer` / `fin_amanecer` | Horario de la ventana de amanecer (HH:MM). Actualizados automáticamente si AUTO_SYNC=ON |
| `inicio_atardecer` / `fin_atardecer` | Horario de la ventana de atardecer (HH:MM). Actualizados automáticamente si AUTO_SYNC=ON |
| `AUTO_SYNC` | ON/OFF — si ON, los horarios se recalculan automáticamente con astral al final de cada ventana |
| `duracion_amanecer_sync` | Duración de la ventana de amanecer en horas (acepta decimales) |
| `duracion_atardecer_sync` | Duración de la ventana de atardecer en horas (acepta decimales) |
| `offset_amanecer_sync` | Offset en minutos respecto al amanecer astronómico (positivo = retrasa, negativo = adelanta) |
| `offset_atardecer_sync` | Offset en minutos respecto al atardecer astronómico |

### config_general.txt

| Parámetro | Descripción |
|---|---|
| `FIRST_START` | TRUE/FALSE — si TRUE, activa el modo hotspot de configuración inicial al arrancar |
| `LAT` / `LON` | Coordenadas GPS del lugar de instalación. Se obtienen automáticamente via ipinfo.io en el primer arranque |
| `SSID` / `PASSWORD` | Credenciales de la red WiFi. Se actualizan automáticamente via el portal hotspot |
| `CONSUMO_WH` | Consumo estimado por ventana de grabación en Wh (valor medido: 2.87W × duración en horas) |
| `CAPACIDAD_MAH` | Capacidad total de la batería en mAh |
| `VOLTAJE_BATERIA` | Voltaje nominal de la batería en V (3.7V para LiPo celda única) |
| `MARGEN_SEGURIDAD` | Factor multiplicador para el umbral de batería (1.5 = 50% de margen de seguridad) |

---

## Control remoto via Google Drive

Una vez el dispositivo está en campo, los archivos `config_horarios.txt` y `config_general.txt` en la carpeta de Google Drive pueden editarse desde cualquier lugar. Los cambios se aplican en el siguiente ciclo de grabación, cuando el dispositivo descarga la versión actualizada de Drive.

El archivo `log_sistema.txt` en Drive se actualiza al final de cada ventana y permite monitorear remotamente el estado del dispositivo: nivel de batería, detecciones registradas y posibles cancelaciones por batería baja.
