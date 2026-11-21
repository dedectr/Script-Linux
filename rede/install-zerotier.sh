#!/usr/bin/env bash
# ============================================================
#  Compila e instala o ZeroTier One
#  Debian/Ubuntu, Arch, Fedora, Void, openSUSE e Alpine
# ============================================================

set -euo pipefail

if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
else
    C_RESET="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE=""
fi

info() { printf '%sℹ️  %s%s\n' "$C_BLUE" "$*" "$C_RESET"; }
ok()   { printf '%s✅ %s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
warn() { printf '%s⚠️  %s%s\n' "$C_YELLOW" "$*" "$C_RESET"; }
die()  { printf '%s❌ %s%s\n' "$C_RED" "$*" "$C_RESET" >&2; exit 1; }

# ------------------------------------------------------------
# Verificações
# ------------------------------------------------------------
[[ $EUID -eq 0 ]] || die "Execute como root: sudo $0"

if command -v xbps-install >/dev/null 2>&1; then
    PM="void"
elif command -v apt >/dev/null 2>&1; then
    PM="debian"
elif command -v pacman >/dev/null 2>&1; then
    PM="arch"
elif command -v dnf >/dev/null 2>&1; then
    PM="fedora"
elif command -v zypper >/dev/null 2>&1; then
    PM="opensuse"
elif command -v apk >/dev/null 2>&1; then
    PM="alpine"
else
    die "Gerenciador de pacotes não reconhecido."
fi

info "Gerenciador detectado: $PM"
info "Instalando dependências de compilação..."

case "$PM" in
    void)
        xbps-install -Sy base-devel cmake make gcc g++ git \
            libminiupnpc-devel libnatpmp-devel openssl-devel pkg-config
        ;;
    debian)
        apt-get update
        apt-get install -y build-essential cmake make gcc g++ git \
            libminiupnpc-dev libnatpmp-dev libssl-dev pkg-config
        ;;
    arch)
        pacman -S --needed --noconfirm base-devel cmake git \
            miniupnpc libnatpmp openssl pkgconf
        ;;
    fedora)
        dnf install -y cmake make gcc gcc-c++ git \
            miniupnpc-devel libnatpmp-devel openssl-devel pkgconf
        ;;
    opensuse)
        zypper --non-interactive install --auto-agree-with-licenses \
            cmake make gcc gcc-c++ git \
            miniupnpc-devel libnatpmp-devel libopenssl-devel pkg-config
        ;;
    alpine)
        apk add --no-cache build-base cmake git \
            miniupnpc-dev libnatpmp-dev openssl-dev pkgconf
        ;;
esac

# ------------------------------------------------------------
# Compilação
# ------------------------------------------------------------
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

info "Baixando o código-fonte do ZeroTier..."
git clone --depth 1 https://github.com/zerotier/ZeroTierOne.git "$WORKDIR/ZeroTierOne"
cd "$WORKDIR/ZeroTierOne"

JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)"
if ! [[ "$JOBS" =~ ^[0-9]+$ ]] || (( JOBS <= 0 )); then
    JOBS=2
fi
info "Compilando com $JOBS job(s)..."
make -j"$JOBS"

info "Instalando..."
make install

ZT_BIN="/usr/local/sbin/zerotier-one"
ZT_CLI="/usr/local/sbin/zerotier-cli"

[[ -x "$ZT_BIN" ]] || die "O binário não foi encontrado em $ZT_BIN."
[[ -x "$ZT_CLI" ]] || warn "O comando zerotier-cli não foi encontrado em $ZT_CLI."

# ------------------------------------------------------------
# Serviço
# ------------------------------------------------------------
if [[ ! -c /dev/net/tun ]]; then
    warn "Dispositivo TUN não encontrado. Tentando carregar o módulo..."
    modprobe tun 2>/dev/null || warn "Ative o suporte a TUN no kernel para usar o ZeroTier."
fi

info "Configurando o serviço..."

if [[ -d /run/systemd/system ]] && command -v systemctl >/dev/null 2>&1; then
    cat > /etc/systemd/system/zerotier-one.service <<EOF
[Unit]
Description=ZeroTier One
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$ZT_BIN
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now zerotier-one.service
    ok "Serviço systemd zerotier-one ativo."
elif command -v rc-service >/dev/null 2>&1; then
    cat > /etc/init.d/zerotier-one <<EOF
#!/sbin/openrc-run
description="ZeroTier One"
command="$ZT_BIN"
command_background=true
pidfile="/run/zerotier-one.pid"
EOF
    chmod +x /etc/init.d/zerotier-one
    rc-update add zerotier-one default
    rc-service zerotier-one restart
    ok "Serviço OpenRC zerotier-one ativo."
elif command -v sv >/dev/null 2>&1; then
    mkdir -p /etc/sv/zerotier-one
    cat > /etc/sv/zerotier-one/run <<EOF
#!/bin/sh
exec $ZT_BIN
EOF
    chmod +x /etc/sv/zerotier-one/run
    ln -sfn /etc/sv/zerotier-one /var/service/
    sv restart zerotier-one 2>/dev/null || sv start zerotier-one
    ok "Serviço runit zerotier-one ativo."
else
    warn "Nenhum supervisor encontrado. Inicie manualmente: $ZT_BIN"
fi

printf '\n'
ok "ZeroTier compilado e instalado!"
printf '  %sEntrar em uma rede:%s sudo %s join <ID>\n' "$C_YELLOW" "$C_RESET" "$ZT_CLI"
printf '  %sStatus:%s            sudo %s info\n' "$C_YELLOW" "$C_RESET" "$ZT_CLI"
