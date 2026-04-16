#!/bin/sh

echo "[+] Instalando OpenVPN..."
apk update
apk add openvpn easy-rsa iptables

echo "[+] Configurando Easy-RSA..."
make-cadir /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa || exit

# Inicializa PKI
./easyrsa init-pki

echo "[+] Criando CA..."
echo | ./easyrsa build-ca nopass

echo "[+] Criando certificado do servidor..."
./easyrsa gen-req server nopass
echo yes | ./easyrsa sign-req server server

echo "[+] Gerando Diffie-Hellman..."
./easyrsa gen-dh

echo "[+] Gerando TLS key..."
openvpn --genkey --secret ta.key

echo "[+] Copiando arquivos..."
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
push "dhcp-option DNS 8.8.8.8"

keepalive 10 120
cipher AES-256-CBC
user nobody
group nobody

status openvpn-status.log
verb 3
EOF

echo "[+] Ativando IP Forward..."
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

echo "[+] Configurando NAT..."
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

echo "[+] Iniciando OpenVPN..."
rc-service openvpn start
rc-update add openvpn

echo "[+] Pronto! Agora falta criar cliente."
