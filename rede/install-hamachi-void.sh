#!/usr/bin/env bash
# ============================================================
#  Hamachi no Void Linux
# ============================================================

set -euo pipefail

VERSION="2.1.0.203"
URL="https://www.vpn.net/installers/logmein-hamachi_${VERSION}-1_amd64.tar.gz"

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
command -v xbps-install >/dev/null 2>&1 || die "Este script é exclusivo para Void Linux."

if [[ "$(uname -m)" != "x86_64" ]]; then
    die "O pacote oficial do Hamachi disponível é apenas para x86_64."
fi

if [[ $EUID -ne 0 ]]; then
    command -v sudo >/dev/null 2>&1 || die "sudo não encontrado."
fi

SUDO=""
[[ $EUID -ne 0 ]] && SUDO="sudo"

# Dependências básicas
for cmd in wget tar make; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        info "Instalando dependência: $cmd"
        $SUDO xbps-install -y "$cmd"
    fi
done

# ------------------------------------------------------------
# Download e instalação
# ------------------------------------------------------------
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

info "Baixando Hamachi $VERSION..."
wget -O "$WORKDIR/hamachi.tar.gz" "$URL"

info "Extraindo..."
tar -xzf "$WORKDIR/hamachi.tar.gz" -C "$WORKDIR"

SRC="$WORKDIR/logmein-hamachi-$VERSION"
[[ -d "$SRC" ]] || die "A pasta extraída não foi encontrada: $SRC"

info "Instalando..."
( cd "$SRC" && $SUDO make install )

[[ -x /opt/logmein-hamachi/bin/hamachi ]] \
    || warn "O binário hamachi não foi encontrado em /opt/logmein-hamachi/bin/."

# ------------------------------------------------------------
# Serviço runit
# ------------------------------------------------------------
info "Criando serviço runit..."
$SUDO mkdir -p /etc/sv/hamachi

$SUDO tee /etc/sv/hamachi/run >/dev/null <<'EOF'
#!/bin/sh
exec /opt/logmein-hamachi/bin/hamachid
EOF

$SUDO chmod +x /etc/sv/hamachi/run
$SUDO ln -sfn /etc/sv/hamachi /var/service/
$SUDO sv restart hamachi 2>/dev/null || $SUDO sv start hamachi 2>/dev/null || true

sleep 2

info "Inicializando Hamachi..."
$SUDO hamachi login || warn "Não foi possível fazer login automaticamente."
$SUDO hamachi agree 2>/dev/null || true

# ------------------------------------------------------------
# Configuração opcional
# ------------------------------------------------------------
printf '\n'
read -rp "Deseja conectar sua conta Hamachi agora? [s/N]: " resp || resp=""
if [[ "${resp,,}" == "s" ]]; then
    read -rp "E-mail da conta LogMeIn/Hamachi: " email || email=""
    if [[ -n "$email" ]]; then
        $SUDO hamachi attach "$email" || warn "Falha ao conectar a conta."
    fi
fi

printf '\n'
read -rp "Deseja entrar em uma rede Hamachi? [s/N]: " resp2 || resp2=""
if [[ "${resp2,,}" == "s" ]]; then
    read -rp "Nome da rede: " network || network=""
    if [[ -n "$network" ]]; then
        read -rsp "Senha da rede: " password || password=""
        printf '\n'
        $SUDO hamachi join "$network" "$password" || warn "Falha ao entrar na rede."
    fi
fi

printf '\n'
ok "Hamachi instalado e rodando em background!"
printf '  %sStatus:%s sudo hamachi\n' "$C_YELLOW" "$C_RESET"
printf '  %sServiço:%s sudo sv status hamachi\n' "$C_YELLOW" "$C_RESET"
