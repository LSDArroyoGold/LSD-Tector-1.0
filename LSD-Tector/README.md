# LSD-Tector 1.0 — Software

Este repositorio contiene todo el software necesario para replicar el sistema de monitoreo autónomo de aves LSD-Tector, desarrollado en el Laboratorio de Sistemas Dinámicos (LSD), Facultad de Ciencias Exactas y Naturales, Universidad de Buenos Aires.

El sistema gestiona automáticamente ventanas de grabación en horarios de amanecer y atardecer, identifica especies mediante BirdNET-Pi, envía detecciones a Google Drive, y administra el ciclo de encendido y apagado de la Raspberry Pi mediante el RTC de la PiJuice HAT. Para una descripción completa del hardware y el diseño físico del dispositivo, referirse al artículo asociado.

Este software fue desarrollado y probado sobre una **Raspberry Pi 4 Model B (4GB RAM)** con una **PiJuice HAT** como módulo de gestión de energía. No se garantiza compatibilidad con otros modelos o configuraciones de hardware.

---

## Dependencias

- Raspberry Pi OS Full 64-bit (Bookworm)
- BirdNET-Pi
- Python 3 (incluido en Raspberry Pi OS)
- rclone
- astral (librería Python)
- API Python de PiJuice
- nmcli (incluido en Raspberry Pi OS)
- hostapd y dnsmasq

---

## Instalación

### 1. Sistema operativo

Instalar **Raspberry Pi OS Full 64-bit (Bookworm)** en la microSD usando [Raspberry Pi Imager](https://www.raspberrypi.com/software/). Durante el proceso de flasheo, en la sección de configuración avanzada del Imager (ícono del engranaje), crear un usuario con nombre y contraseña a elección. En nuestro caso utilizamos:

- Nombre de usuario: `lsd`
- Contraseña: `fourier1822`

> **Nota:** todos los scripts y rutas de este repositorio asumen que el usuario es `lsd` y que los archivos se encuentran en `/home/lsd/`. Si se utiliza un nombre de usuario diferente, será necesario reemplazar `lsd` por el nombre elegido en todas las rutas de los scripts antes de utilizarlos.

Una vez flasheada la microSD, insertarla en la Raspberry Pi y encenderla.

### 2. BirdNET-Pi

Desde la terminal de la RP, ejecutar:

```bash
curl -s https://raw.githubusercontent.com/Nachtzuster/BirdNET-Pi/main/newinstaller.sh | bash
```

La instalación tarda varios minutos. Una vez finalizada, BirdNET-Pi queda corriendo automáticamente y es accesible desde cualquier dispositivo en la misma red ingresando `http://[IP_de_la_RP]` en el navegador.

### 3. Paquetes del sistema

```bash
sudo apt update
sudo apt install hostapd dnsmasq util-linux-extra --reinstall
sudo systemctl enable dnsmasq
sudo systemctl start dnsmasq
```

Verificar que `hwclock` quedó disponible:

```bash
which hwclock
```

Debe devolver `/usr/sbin/hwclock`.

### 4. Habilitar I2C

La PiJuice se comunica con la Raspberry Pi mediante el protocolo I2C. Para habilitarlo:

```bash
sudo raspi-config
```

Navegar a **Interface Options → I2C → Enable**. Confirmar y salir. Luego reiniciar:

```bash
sudo reboot
```

Verificar que la PiJuice es detectada correctamente en el bus I2C (debe aparecer `14` en la dirección 0x14):

```bash
sudo i2cdetect -y 1
```

### 5. Dependencias Python

```bash
pip install astral --break-system-packages
```

### 6. API Python de PiJuice

El paquete oficial de PiJuice no está disponible en los repositorios estándar de Raspberry OS. Instalarlo directamente desde GitHub:

```bash
git clone https://github.com/PiSupply/PiJuice.git /home/lsd/BirdNET-Pi/PiJuice
cd /home/lsd/BirdNET-Pi/PiJuice/Software/Source
pip install . --break-system-packages
```

Verificar que la API funciona correctamente:

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

Si la PiJuice responde sin errores, la instalación fue exitosa.

### 7. Clonar el repositorio

Clonar este repositorio en la Raspberry Pi:

```bash
cd /home/lsd
git clone https://github.com/TU_USUARIO/LSD-Tector-1.0.git
```

Copiar los scripts y archivos de configuración a `/home/lsd/`:

```bash
cp /home/lsd/LSD-Tector-1.0/scripts/* /home/lsd/
cp /home/lsd/LSD-Tector-1.0/python/* /home/lsd/
cp /home/lsd/LSD-Tector-1.0/config/* /home/lsd/
chmod +x /home/lsd/*.sh
```

Copiar los archivos de configuración de systemd y hostapd:

```bash
sudo cp /home/lsd/LSD-Tector-1.0/systemd/hostapd.conf /etc/hostapd/hostapd.conf
sudo cp /home/lsd/LSD-Tector-1.0/systemd/sync-rtc.service /etc/systemd/system/
sudo cp /home/lsd/LSD-Tector-1.0/systemd/hotspot.service /etc/systemd/system/
sudo systemctl daemon-reload
```
 **Nota:** el asterisco `*` es un comodín de bash que significa "todos los archivos". Por ejemplo, `scripts/*` copia todos los archivos dentro de la carpeta `scripts/`.

