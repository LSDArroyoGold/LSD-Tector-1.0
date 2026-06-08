#!/bin/bash

export RCLONE_CONFIG=/home/lsd/.config/rclone/rclone.conf

HORARIO=$(awk -F' = ' '/inicio_atardecer/{print $2}' /home/lsd/config_horarios.txt | tr -d '\r')
HORA_ACTUAL=$(date +%H:%M)

HORARIO_DELAY=$(echo "$HORARIO" | awk -F: '{m=$2+2; h=$1; if(m>=60){m=m-60} printf "%02d:%02d\n", h, m}')

if [ "$HORA_ACTUAL" = "$HORARIO_DELAY" ]; then

	CONSUMO_WH=$(awk -F'=' '/CONSUMO_WH/{print $2}' /home/lsd/config_general.txt | tr -d ' \r')
	CAPACIDAD_MAH=$(awk -F'=' '/CAPACIDAD_MAH/{print $2}' /home/lsd/config_general.txt | tr -d ' \r')
	VOLTAJE=$(awk -F'=' '/VOLTAJE_BATERIA/{print $2}' /home/lsd/config_general.txt | tr -d ' \r')
	MARGEN=$(awk -F'=' '/MARGEN_SEGURIDAD/{print $2}' /home/lsd/config_general.txt | tr -d ' \r')

	UMBRAL=$(python3 -c "
consumo=$CONSUMO_WH
capacidad_mah=$CAPACIDAD_MAH
voltaje=$VOLTAJE
margen=$MARGEN
capacidad_wh = (capacidad_mah / 1000) * voltaje
umbral = (consumo / capacidad_wh) * 100 * margen
print(int(umbral))
")

	NIVEL=$(python3 -c "
import sys
sys.path.append('/home/lsd/BirdNET-Pi/PiJuice/Software/Source')
from pijuice import PiJuice
pj = PiJuice(1, 0x14)
print(pj.status.GetChargeLevel()['data'])
")

	if [ "$NIVEL" -lt "$UMBRAL" ]; then
		# Batería insuficiente: cancelar ventana
		python3 /home/lsd/log_sistema.py CANCELADA atardecer
		sudo nmcli radio wifi on
		INTENTOS=0
		until ping -c 1 google.com &>/dev/null || [ $INTENTOS -ge 6 ]; do
			sleep 5
			INTENTOS=$((INTENTOS + 1))
		done
		if ping -c 1 google.com &>/dev/null; then
			rclone copy /home/lsd/log_sistema.txt gdrive:Laboratorio\ 6/
		fi
		sudo nmcli radio wifi off
		HORA_WAKE=$(awk -F' = ' '/inicio_amanecer/{print $2}' /home/lsd/config_horarios.txt | tr -d '\r')
		python3 /home/lsd/set_wake_pijuice.py $HORA_WAKE
		python3 -c "
import sys
sys.path.append('/home/lsd/BirdNET-Pi/PiJuice/Software/Source')
from pijuice import PiJuice
pj = PiJuice(1, 0x14)
pj.power.SetPowerOff(10)
"
		sudo poweroff
	else
		# Batería suficiente: registrar inicio y subir log
		python3 /home/lsd/log_sistema.py INICIO atardecer
		sudo nmcli radio wifi on
		INTENTOS=0
		until ping -c 1 google.com &>/dev/null || [ $INTENTOS -ge 6 ]; do
			sleep 5
			INTENTOS=$((INTENTOS + 1))
		done
		if ping -c 1 google.com &>/dev/null; then
			rclone copy /home/lsd/log_sistema.txt gdrive:Laboratorio\ 6/
		fi
		sudo nmcli radio wifi off
	fi
fi
