#!/bin/sh
# ============================================================
#  Servidor OpenVPN com easy-rsa + menu de clientes
#
#  Variáveis opcionais:
#    OPENVPN_PORT, OPENVPN_PROTO, OPENVPN_IP, OPENVPN_IFACE,
#    OPENVPN_NET, OPENVPN_MASK, OPENVPN_CIDR,
#    OPENVPN_DNS1, OPENVPN_DNS2
# ============================================================

set -eu
umask 077

# ------------------------------------------------------------
# Cores e mensagens
# ------------------------------------------------------------
if [ -t 1 ]; then
    C_RESET=$(printf '\033[0m')
    C_RED=$(printf '\033[31m')
    C_GREEN=$(printf '\033[32m')
    C_YELLOW=$(printf '\033[33m')
    C_BLUE=$(printf '\033[34m')
else
    C_RESET="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE=""
fi

info() { printf '%s[+] %s%s\n' "$C_BLUE" "$*" "$C_RESET"; }
ok()   { printf '%s[ok] %s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
warn() { printf '%s[!] %s%s\n' "$C_YELLOW" "$*" "$C_RESET"; }
die()  { printf '%s[x] %s%s\n' "$C_RED" "$*" "$C_RESET" >&2; exit 1; }

# ------------------------------------------------------------
# Configuração
# ------------------------------------------------------------
BASE="/etc/openvpn"
SERVER_DIR="$BASE/server"
EASY="$BASE/easy-rsa"
CLIENTS="$BASE/clients"
PKI="$EASY/pki"
CONF="$SERVER_DIR/server.conf"

PORT="${OPENVPN_PORT:-1194}"
PROTO="${OPENVPN_PROTO:-udp}"
VPN_NET="${OPENVPN_NET:-10.8.0.0}"
VPN_MASK="${OPENVPN_MASK:-255.255.255.0}"
VPN_CIDR="${OPENVPN_CIDR:-10.8.0.0/24}"
DNS1="${OPENVPN_DNS1:-1.1.1.1}"
DNS2="${OPENVPN_DNS2:-8.8.8.8}"

# ------------------------------------------------------------
# Verificações iniciais
# ------------------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "Execute como root: sudo $0"

if command -v apk >/dev/null 2>&1; then
    PM="apk"
elif command -v apt >/dev/null 2>&1; then
    PM="apt"
elif command -v dnf >/dev/null 2>&1; then
    PM="dnf"
elif command -v pacman >/dev/null 2>&1; then
    PM="pacman"
elif command -v xbps-install >/dev/null 2>&1; then
    PM="xbps"
elif command -v zypper >/dev/null 2>&1; then
    PM="zypper"
else
    die "Distribuição não suportada."
fi

install_deps() {
    info "Instalando dependências..."
    case "$PM" in
        apk)     apk add --no-cache openvpn easy-rsa iptables curl qrencode ;;
        apt)     apt-get update && apt-get install -y openvpn easy-rsa iptables nftables curl qrencode ;;
        dnf)     dnf install -y openvpn easy-rsa iptables nftables curl qrencode ;;
        pacman)  pacman -S --needed --noconfirm openvpn easy-rsa iptables-nft curl qrencode ;;
        xbps)    xbps-install -Sy openvpn easy-rsa iptables curl qrencode ;;
        zypper)  zypper --non-interactive install openvpn easy-rsa iptables curl qrencode ;;
    esac
}

# ------------------------------------------------------------
# Utilidades
# ------------------------------------------------------------
setup_easyrsa() {
    mkdir -p "$BASE"

    if [ ! -x "$EASY/easyrsa" ]; then
        if command -v make-cadir >/dev/null 2>&1; then
            make-cadir "$EASY"
        elif [ -d /usr/share/easy-rsa ]; then
            mkdir -p "$EASY"
            cp -a /usr/share/easy-rsa/. "$EASY/"
        elif [ -d /usr/share/easy-rsa-3 ]; then
            mkdir -p "$EASY"
            cp -a /usr/share/easy-rsa-3/. "$EASY/"
        else
            die "easy-rsa não encontrado. Instale o pacote easy-rsa."
        fi
    fi

    chmod 700 "$EASY"
}

gen_ta_key() {
    [ -f "$SERVER_DIR/ta.key" ] && return 0

    if ! ( cd "$SERVER_DIR" && openvpn --genkey secret ta.key ) 2>/dev/null; then
        ( cd "$SERVER_DIR" && openvpn --genkey --secret ta.key )
    fi
}

detect_ip() {
    _detected_ip=""

    if command -v curl >/dev/null 2>&1; then
        _detected_ip=$(curl -4 -fsS --max-time 10 https://ifconfig.me 2>/dev/null || true)
        [ -n "$_detected_ip" ] || _detected_ip=$(curl -4 -fsS --max-time 10 https://api.ipify.org 2>/dev/null || true)
    fi

    if [ -z "$_detected_ip" ] && command -v ip >/dev/null 2>&1; then
        _detected_ip=$(ip route get 1.1.1.1 2>/dev/null \
            | awk '{for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit }}')
    fi

    printf '%s' "$_detected_ip"
}

# ------------------------------------------------------------
# Configuração do servidor
# ------------------------------------------------------------
setup_server() {
    info "Configurando o servidor OpenVPN..."

    setup_easyrsa
    mkdir -p "$SERVER_DIR" "$CLIENTS"
    chmod 700 "$SERVER_DIR" "$CLIENTS"

    if [ ! -d "$PKI" ]; then
        ( cd "$EASY" && EASYRSA_BATCH=1 ./easyrsa init-pki )
    fi

    if [ ! -f "$PKI/ca.crt" ]; then
        info "Criando a CA..."
        ( cd "$EASY" && EASYRSA_BATCH=1 ./easyrsa build-ca nopass )
    fi

    if [ ! -f "$PKI/private/server.key" ]; then
        info "Gerando a chave do servidor..."
        ( cd "$EASY" && EASYRSA_BATCH=1 ./easyrsa gen-req server nopass )
    fi

    if [ ! -f "$PKI/issued/server.crt" ]; then
        info "Assinando o certificado do servidor..."
        ( cd "$EASY" && EASYRSA_BATCH=1 ./easyrsa sign-req server server )
    fi

    if [ ! -f "$PKI/dh.pem" ]; then
        info "Gerando parâmetros Diffie-Hellman (pode demorar)..."
        ( cd "$EASY" && EASYRSA_BATCH=1 ./easyrsa gen-dh )
    fi

    if [ ! -f "$PKI/crl.pem" ]; then
        ( cd "$EASY" && EASYRSA_BATCH=1 ./easyrsa gen-crl )
    fi

    cp "$PKI/ca.crt" "$SERVER_DIR/ca.crt"
    cp "$PKI/private/server.key" "$SERVER_DIR/server.key"
    cp "$PKI/issued/server.crt" "$SERVER_DIR/server.crt"
    cp "$PKI/dh.pem" "$SERVER_DIR/dh.pem"
    cp "$PKI/crl.pem" "$SERVER_DIR/crl.pem"

    chmod 644 "$SERVER_DIR/ca.crt" "$SERVER_DIR/server.crt" \
        "$SERVER_DIR/dh.pem" "$SERVER_DIR/crl.pem"
    chmod 600 "$SERVER_DIR/server.key"

    gen_ta_key

    # Scripts de NAT executados quando a interface tun sobe/desce
    cat > "$SERVER_DIR/up.sh" <<EOF
#!/bin/sh
iptables -t nat -C POSTROUTING -s "$VPN_CIDR" -o "$IFACE" -j MASQUERADE 2>/dev/null ||
iptables -t nat -A POSTROUTING -s "$VPN_CIDR" -o "$IFACE" -j MASQUERADE
EOF

    cat > "$SERVER_DIR/down.sh" <<EOF
#!/bin/sh
iptables -t nat -D POSTROUTING -s "$VPN_CIDR" -o "$IFACE" -j MASQUERADE 2>/dev/null || true
EOF

    chmod 700 "$SERVER_DIR/up.sh" "$SERVER_DIR/down.sh"

    # Configuração do servidor
    cat > "$CONF" <<EOF
port $PORT
proto $PROTO
dev tun
topology subnet

ca $SERVER_DIR/ca.crt
cert $SERVER_DIR/server.crt
key $SERVER_DIR/server.key
dh $SERVER_DIR/dh.pem
tls-auth $SERVER_DIR/ta.key 0
crl-verify $SERVER_DIR/crl.pem

server $VPN_NET $VPN_MASK
ifconfig-pool-persist $SERVER_DIR/ipp.txt

push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS $DNS1"
push "dhcp-option DNS $DNS2"

keepalive 10 120
persist-key
persist-tun
script-security 2
up $SERVER_DIR/up.sh
down $SERVER_DIR/down.sh
verb 3
EOF

    chmod 600 "$CONF"

    printf 'net.ipv4.ip_forward=1\n' > /etc/sysctl.d/99-openvpn.conf
    sysctl --system >/dev/null 2>&1 \
        || sysctl -p /etc/sysctl.d/99-openvpn.conf >/dev/null 2>&1 \
        || warn "Ative net.ipv4.ip_forward manualmente."

    ok "Servidor configurado em $CONF"
}

# ------------------------------------------------------------
# Serviço
# ------------------------------------------------------------
start_service() {
    info "Configurando e iniciando o serviço..."

    if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
        cat > /etc/systemd/system/openvpn-server.service <<EOF
[Unit]
Description=OpenVPN Server (Script-Linux)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$OPENVPN_BIN --config $CONF
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable openvpn-server.service
        systemctl restart openvpn-server.service
        ok "Serviço systemd openvpn-server ativo."
    elif command -v rc-service >/dev/null 2>&1; then
        cat > /etc/init.d/openvpn-server <<EOF
#!/sbin/openrc-run
description="OpenVPN Server (Script-Linux)"
command="$OPENVPN_BIN"
command_args="--config $CONF"
command_background=true
pidfile="/run/openvpn-server.pid"
EOF
        chmod +x /etc/init.d/openvpn-server
        rc-update add openvpn-server default
        rc-service openvpn-server restart
        ok "Serviço OpenRC openvpn-server ativo."
    elif command -v sv >/dev/null 2>&1; then
        mkdir -p /etc/sv/openvpn-server
        cat > /etc/sv/openvpn-server/run <<EOF
#!/bin/sh
exec $OPENVPN_BIN --config $CONF 2>&1
EOF
        chmod +x /etc/sv/openvpn-server/run
        ln -sfn /etc/sv/openvpn-server /var/service/
        sv restart openvpn-server 2>/dev/null || sv start openvpn-server
        ok "Serviço runit openvpn-server ativo."
    else
        warn "Nenhum supervisor encontrado. Inicie manualmente:"
        printf '  %s --config %s\n' "$OPENVPN_BIN" "$CONF"
    fi
}

restart_service() {
    if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
        systemctl restart openvpn-server.service 2>/dev/null || true
    elif command -v rc-service >/dev/null 2>&1; then
        rc-service openvpn-server restart 2>/dev/null || true
    elif command -v sv >/dev/null 2>&1; then
        sv restart openvpn-server 2>/dev/null || true
    fi
}

status_service() {
    if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
        systemctl status openvpn-server.service --no-pager 2>/dev/null || true
    elif command -v rc-service >/dev/null 2>&1; then
        rc-service openvpn-server status 2>/dev/null || true
    elif command -v sv >/dev/null 2>&1; then
        sv status openvpn-server 2>/dev/null || true
    else
        pgrep -f "openvpn.*$CONF" >/dev/null 2>&1 && echo "online" || echo "offline"
    fi
}

# ------------------------------------------------------------
# Clientes
# ------------------------------------------------------------
create_client() {
    printf 'Nome do cliente: '
    read -r NAME || die "Entrada cancelada."

    case "$NAME" in
        ""|*[!A-Za-z0-9_-]*)
            die "Use apenas letras, números, _ e - no nome."
            ;;
    esac

    [ ! -f "$CLIENTS/$NAME.ovpn" ] || die "O cliente '$NAME' já existe."
    [ ! -f "$PKI/issued/$NAME.crt" ] || die "Já existe um certificado para '$NAME'."

    info "Gerando certificado para $NAME..."
    ( cd "$EASY" && EASYRSA_BATCH=1 ./easyrsa gen-req "$NAME" nopass )
    ( cd "$EASY" && EASYRSA_BATCH=1 ./easyrsa sign-req client "$NAME" )

    OVPN="$CLIENTS/$NAME.ovpn"

    cat > "$OVPN" <<EOF
client
dev tun
proto $PROTO
remote $IP $PORT
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
key-direction 1
verb 3

<ca>
$(cat "$SERVER_DIR/ca.crt")
</ca>

<cert>
$(cat "$PKI/issued/$NAME.crt")
</cert>

<key>
$(cat "$PKI/private/$NAME.key")
</key>

<tls-auth>
$(cat "$SERVER_DIR/ta.key")
</tls-auth>
EOF

    chmod 600 "$OVPN"
    ok "Cliente criado: $OVPN"

    if command -v qrencode >/dev/null 2>&1; then
        info "QR Code do perfil:"
        qrencode -t ansiutf8 < "$OVPN"
    fi
}

revoke_client() {
    printf 'Nome do cliente: '
    read -r NAME || die "Entrada cancelada."

    case "$NAME" in
        ""|*[!A-Za-z0-9_-]*)
            die "Nome inválido."
            ;;
    esac

    [ -f "$PKI/issued/$NAME.crt" ] || die "Cliente '$NAME' não encontrado."

    info "Revogando certificado de $NAME..."
    ( cd "$EASY" && EASYRSA_BATCH=1 ./easyrsa revoke "$NAME" )
    ( cd "$EASY" && EASYRSA_BATCH=1 ./easyrsa gen-crl )

    cp "$PKI/crl.pem" "$SERVER_DIR/crl.pem"
    chmod 644 "$SERVER_DIR/crl.pem"
    rm -f "$CLIENTS/$NAME.ovpn"

    restart_service
    ok "Cliente '$NAME' revogado."
}

list_clients() {
    info "Clientes configurados:"
    found=0
    for file in "$CLIENTS"/*.ovpn; do
        [ -e "$file" ] || continue
        printf '  - %s\n' "${file##*/}"
        found=1
    done
    [ "$found" -eq 1 ] || printf '  Nenhum cliente.\n'
}

# ------------------------------------------------------------
# Menu
# ------------------------------------------------------------
menu() {
    while true; do
        printf '\n'
        printf '%s=========================================%s\n' "$C_BLUE" "$C_RESET"
        printf '%s            OPENVPN PANEL%s\n' "$C_BLUE" "$C_RESET"
        printf '%s=========================================%s\n' "$C_BLUE" "$C_RESET"
        printf '1) Criar cliente\n'
        printf '2) Revogar cliente\n'
        printf '3) Listar clientes\n'
        printf '4) Iniciar/reiniciar servidor\n'
        printf '5) Status do serviço\n'
        printf '6) Sair\n'
        printf '%s=========================================%s\n' "$C_BLUE" "$C_RESET"
        printf 'Escolha: '
        read -r OPT || exit 0

        case "$OPT" in
            1) create_client ;;
            2) revoke_client ;;
            3) list_clients ;;
            4) start_service ;;
            5) status_service ;;
            6) exit 0 ;;
            *) warn "Opção inválida." ;;
        esac
    done
}

# ------------------------------------------------------------
# Execução principal
# ------------------------------------------------------------
install_deps

OPENVPN_BIN=$(command -v openvpn || true)
[ -n "$OPENVPN_BIN" ] || die "O comando openvpn não foi encontrado."

IFACE="${OPENVPN_IFACE:-}"
if [ -z "$IFACE" ] && command -v ip >/dev/null 2>&1; then
    IFACE=$(ip route 2>/dev/null | awk '/^default/ {print $5; exit}')
fi
[ -n "$IFACE" ] || IFACE="eth0"
[ -e "/sys/class/net/$IFACE" ] || warn "A interface '$IFACE' não existe. Ajuste OPENVPN_IFACE se necessário."

IP="${OPENVPN_IP:-$(detect_ip)}"
[ -n "$IP" ] || die "Não foi possível detectar o IP público. Defina OPENVPN_IP=seu.ip."

info "Interface de saída: $IFACE"
info "IP público: $IP"

mkdir -p "$CLIENTS"
chmod 700 "$CLIENTS"

if [ ! -f "$CONF" ]; then
    setup_server
    start_service
else
    info "Servidor já configurado em $CONF."
fi

menu
