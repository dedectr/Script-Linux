#!/usr/bin/env bash
# ============================================================
#  Instala o yay (AUR helper) no Arch Linux
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
    die "Não execute como root. O makepkg precisa de um usuário normal."
fi

command -v sudo >/dev/null 2>&1 || die "sudo não encontrado."

if command -v yay >/dev/null 2>&1; then
    ok "yay já está instalado: $(yay --version | head -n 1)"
    exit 0
fi

# ------------------------------------------------------------
# Dependências
# ------------------------------------------------------------
info "Instalando dependências (base-devel e git)..."
sudo pacman -S --needed --noconfirm base-devel git

# ------------------------------------------------------------
# Compilação
# ------------------------------------------------------------
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

info "Clonando o repositório do yay..."
git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp_dir/yay"

info "Compilando e instalando o yay..."
( cd "$tmp_dir/yay" && makepkg -si --noconfirm )

command -v yay >/dev/null 2>&1 || die "A instalação terminou, mas o comando yay não foi encontrado."

printf '\n'
ok "yay instalado com sucesso!"
info "Versão: $(yay --version | head -n 1)"
