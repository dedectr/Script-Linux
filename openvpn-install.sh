#!/bin/sh

set -e

echo "[+] Instalando pacotes..."
apk update
apk add openvpn easy-rsa iptables iptables-openrc curl

# Detectar interface automaticamente
IFACE=$(ip route | awk '/default/ {print $5; exit}')
[ -z "$IFACE" ] && IFACE="eth0"

# Detectar IP
IP=$(curl -s ifconfig.me || true)
[ -z "$IP" ] && IP=$(hostname -I | awk '{print $1}')

echo "[+] Interface: $IFACE"
echo "[+] IP: $IP"

echo "[+] Configurando Easy-RSA..."
make-cadir /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa

./easyrsa init-pki
echo | ./easyrsa build-ca nopass
./easyrsa gen-req server nopass
echo yes | ./easyrsa sign-req server server
./easyrsa gen-dh

openvpn --genkey --secret ta.key

cp pki/ca.crt /etc/openvpn/
cp pki/private/server.key /etc/openvpn/
cp pki/issued/server.crt /etc/openvpn/
cp pki/dh.pem /etc/openvpn/
cp ta.key /etc/openvpn/

echo "[+] Criando config do servidor..."
cat > /etc/openvpn/server.conf <<EOF
port 1194
proto udp
dev tun

ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0

server 10.8.0.0 255.255.255.0
persist-key
persist-tun

push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"

keepalive 10 120
cipher AES-256-CBC

status openvpn-status.log
verb 3
EOF

echo "[+] Ativando IP forward..."
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-openvpn.conf
sysctl -p /etc/sysctl.d/99-openvpn.conf

echo "[+] Configurando NAT..."
iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE

# Persistir iptables
rc-update add iptables
rc-service iptables save

echo "[+] Criando cliente..."
cd /etc/openvpn/easy-rsa
./easyrsa gen-req client nopass
echo yes | ./easyrsa sign-req client client

CLIENT_OVPN=/root/client.ovpn

cat > $CLIENT_OVPN <<EOF
client
dev tun
proto udp
remote $IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
key-direction 1
verb 3

<ca>
$(cat /etc/openvpn/ca.crt)
</ca>

<cert>
$(cat pki/issued/client.crt)
</cert>

<key>
$(cat pki/private/client.key)
</key>

<tls-auth>
$(cat /etc/openvpn/ta.key)
</tls-auth>
EOF

echo "[+] Iniciando OpenVPN..."

# OpenRC usa nome da config
rc-service openvpn start || openvpn --config /etc/openvpn/server.conf &

rc-update add openvpn

echo ""
echo "===================================="
echo "[✔] VPN PRONTA!"
echo "Arquivo do cliente:"
echo "$CLIENT_OVPN"
echo "===================================="
