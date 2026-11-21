#!/usr/bin/env bash
# ============================================================
#  Hamachi no Arch Linux (via AUR)
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
command -v pacman >/dev/null 2>&1 || die "Este script é exclusivo para Arch Linux e derivados."

if [[ $EUID -eq 0 ]]; then
    die "Não execute como root. O AUR helper (yay/paru) deve rodar como usuário normal."
fi

command -v sudo >/dev/null 2>&1 || die "sudo não encontrado."

AUR_HELPER=""
if command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
elif command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
else
    die "Nenhum AUR helper encontrado. Instale o yay com: ../sistema/yay.sh"
fi

command -v systemctl >/dev/null 2>&1 || die "systemctl não encontrado."

# ------------------------------------------------------------
# Instalação
# ------------------------------------------------------------
info "Usando o AUR helper: $AUR_HELPER"
info "Instalando logmein-hamachi..."
"$AUR_HELPER" -S --needed --noconfirm logmein-hamachi

command -v hamachi >/dev/null 2>&1 || die "O comando hamachi não foi encontrado após a instalação."

info "Ativando o serviço do Hamachi..."
if sudo systemctl enable --now logmein-hamachi; then
    ok "Serviço logmein-hamachi ativo."
else
    warn "Não foi possível ativar o serviço. Verifique: systemctl status logmein-hamachi"
fi

info "Fazendo login no Hamachi..."
sudo hamachi login || warn "Não foi possível fazer login automaticamente. Rode: sudo hamachi login"

printf '\n'
ok "Hamachi instalado!"
printf '  %sConectar conta:%s  sudo hamachi attach seu@email.com\n' "$C_YELLOW" "$C_RESET"
printf '  %sEntrar em rede:%s   sudo hamachi join <rede> <senha>\n' "$C_YELLOW" "$C_RESET"
printf '  %sStatus:%s          sudo hamachi\n' "$C_YELLOW" "$C_RESET"
