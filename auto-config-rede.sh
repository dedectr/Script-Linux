#!/bin/sh

echo "Detectando interfaces..."

# Ativar loopback
ip link set lo up

# Listar todas interfaces (menos lo)
for iface in $(ls /sys/class/net | grep -v lo); do
    echo "Ativando $iface..."

    # Ativa interface
    ip link set "$iface" up

    # Tenta pegar IP via DHCP
    echo "Pegando IP em $iface..."
    udhcpc -i "$iface" -q -n

done

echo "Todas interfaces foram processadas!"
