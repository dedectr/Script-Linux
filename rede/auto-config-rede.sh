#!/bin/sh
# ============================================================
#  Ativa as interfaces de rede e solicita IP via DHCP
#  Requer root. Funciona com udhcpc, dhclient ou dhcpcd.
# ============================================================

set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Execute como root: sudo $0" >&2
    exit 1
fi

if ! command -v ip >/dev/null 2>&1; then
    echo "Erro: comando 'ip' não encontrado (instale iproute2)." >&2
    exit 1
fi

if command -v udhcpc >/dev/null 2>&1; then
    DHCP="udhcpc"
elif command -v dhclient >/dev/null 2>&1; then
    DHCP="dhclient"
elif command -v dhcpcd >/dev/null 2>&1; then
    DHCP="dhcpcd"
else
    echo "Erro: nenhum cliente DHCP encontrado (udhcpc, dhclient ou dhcpcd)." >&2
    exit 1
fi

echo "Cliente DHCP: $DHCP"
echo "Ativando loopback..."
ip link set lo up 2>/dev/null || echo "Aviso: não foi possível ativar o loopback."

# Prefere interfaces físicas; se não encontrar nenhuma, usa todas menos lo.
INTERFACES=""
for path in /sys/class/net/*; do
    [ -e "$path" ] || continue
    iface=${path##*/}
    [ "$iface" = "lo" ] && continue
    if [ -e "$path/device" ] || [ -d "$path/wireless" ]; then
        INTERFACES="$INTERFACES $iface"
    fi
done

if [ -z "$INTERFACES" ]; then
    for path in /sys/class/net/*; do
        [ -e "$path" ] || continue
        iface=${path##*/}
        [ "$iface" = "lo" ] && continue
        INTERFACES="$INTERFACES $iface"
    done
fi

if [ -z "$INTERFACES" ]; then
    echo "Nenhuma interface de rede encontrada." >&2
    exit 1
fi

success=0
failed=0

for iface in $INTERFACES; do
    echo
    echo "== Interface: $iface =="

    if ! ip link set "$iface" up 2>/dev/null; then
        echo "Falha ao ativar $iface."
        failed=$((failed + 1))
        continue
    fi

    echo "Solicitando IP via DHCP..."

    rc=0
    case "$DHCP" in
        udhcpc)   udhcpc -i "$iface" -q -n || rc=$? ;;
        dhclient) dhclient -1 "$iface" || rc=$? ;;
        dhcpcd)   dhcpcd -1 -t 15 "$iface" || rc=$? ;;
    esac

    if [ "$rc" -eq 0 ]; then
        echo "IP obtido em $iface."
        success=$((success + 1))
    else
        echo "Não foi possível obter IP em $iface."
        failed=$((failed + 1))
    fi
done

echo
echo "==========================================="
echo " Interfaces processadas: $success com sucesso, $failed com falha."
echo "==========================================="
