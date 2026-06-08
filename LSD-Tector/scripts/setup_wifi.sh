#!/bin/bash

SSID=$(awk -F'=' '/SSID/{print $2}' /home/lsd/config_general.txt)
PASSWORD=$(awk -F'=' '/PASSWORD/{print $2}' /home/lsd/config_general.txt)

sudo nmcli radio wifi on

if ! nmcli connection show | grep -q "SSID"; then
	nmcli device wifi connect "$SSID" password "$PASSWORD"
	echo "Red $SSID guardada correctamente"
else
	echo "Red $SSID ya estaba guardada"
fi
