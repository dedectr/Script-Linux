#!/bin/sh
set -e

BASE="/etc/openvpn"
EASY="$BASE/easy-rsa"
CLIENTS="$BASE/clients"
PKI="$EASY/pki"

mkdir -p "$CLIENTS"

echo "[+] Detectando sistema..."

# package manager
if command -v apk >/dev/null; then PM="apk"
elif command -v apt >/dev/null; then PM="apt"
elif command -v dnf >/dev/null; then PM="dnf"
elif command -v pacman >/dev/null; then PM="pacman"
elif command -v xbps-install >/dev/null; then PM="xbps"
else echo "[-] distro não suportada"; exit 1
fi

install() {
case "$PM" in
apk) apk add openvpn easy-rsa iptables curl qrencode ;;
apt) apt update && apt install -y openvpn easy-rsa iptables nftables curl qrencode ;;
dnf) dnf install -y openvpn easy-rsa iptables nftables curl qrencode ;;
pacman) pacman -Sy --noconfirm openvpn easy-rsa iptables-nft curl qrencode ;;
xbps) xbps-install -Sy openvpn easy-rsa iptables curl qrencode ;;
esac
}

install

IFACE=$(ip route | awk '/default/ {print $5; exit}')
[ -z "$IFACE" ] && IFACE="eth0"

IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')

echo "[+] Interface: $IFACE"
echo "[+] IP: $IP"

setup_server() {

echo "[+] Configurando servidor..."

make-cadir "$EASY" 2>/dev/null || true
cd "$EASY"

./easyrsa init-pki
echo | ./easyrsa build-ca nopass

./easyrsa gen-req server nopass
echo yes | ./easyrsa sign-req server server
./easyrsa gen-dh
openvpn --genkey --secret ta.key

mkdir -p "$BASE"

cp pki/ca.crt "$BASE/"
cp pki/private/server.key "$BASE/"
cp pki/issued/server.crt "$BASE/"
cp pki/dh.pem "$BASE/"
cp ta.key "$BASE/"

cat > "$BASE/server.conf" <<EOF
port 1194
proto udp
dev tun

ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0

server 10.8.0.0 255.255.255.0

push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"

keepalive 10 120
persist-key
persist-tun
verb 3
EOF

echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-openvpn.conf
sysctl -p >/dev/null 2>&1 || true

# NAT (iptables fallback)
iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null || true

echo "[+] Servidor pronto"
}

start_service() {
if command -v systemctl >/dev/null 2>&1; then
    systemctl enable openvpn-server@server
    systemctl restart openvpn-server@server
elif command -v rc-service >/dev/null 2>&1; then
    rc-update add openvpn default
    rc-service openvpn restart
else
    openvpn --config "$BASE/server.conf" &
fi
}

create_client() {

read -p "Nome do cliente: " NAME

cd "$EASY"

./easyrsa gen-req "$NAME" nopass
echo yes | ./easyrsa sign-req client "$NAME"

OVPN="$CLIENTS/$NAME.ovpn"

cat > "$OVPN" <<EOF
client
dev tun
proto udp
remote $IP 1194
nobind
persist-key
persist-tun
remote-cert-tls server
verb 3

<ca>
$(cat "$BASE/ca.crt")
</ca>

<cert>
$(cat "$PKI/issued/$NAME.crt")
</cert>

<key>
$(cat "$PKI/private/$NAME.key")
</key>

<tls-auth>
$(cat "$BASE/ta.key")
</tls-auth>
EOF

echo "[+] Cliente criado: $OVPN"

# QR Code
echo "[+] Gerando QR Code..."
qrencode -t ansiutf8 < "$OVPN"

}

revoke_client() {
read -p "Nome do cliente: " NAME

cd "$EASY"
./easyrsa revoke "$NAME"
./easyrsa gen-crl

echo "[+] Cliente revogado: $NAME"
}

list_clients() {
echo "[+] Clientes:"
ls "$CLIENTS" 2>/dev/null || echo "Nenhum cliente"
}

menu() {
while true; do
echo ""
echo "========================="
echo "   OPENVPN PANEL"
echo "========================="
echo "1) Criar cliente"
echo "2) Revogar cliente"
echo "3) Listar clientes"
echo "4) Iniciar servidor"
echo "5) Sair"
echo "========================="
read -p "Escolha: " opt

case $opt in
1) create_client ;;
2) revoke_client ;;
3) list_clients ;;
4) start_service ;;
5) exit 0 ;;
*) echo "opção inválida" ;;
esac
done
}

# primeira instalação
if [ ! -f "$BASE/server.conf" ]; then
setup_server
start_service
fi

menu
