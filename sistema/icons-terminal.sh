#!/usr/bin/env bash
# ============================================================
#  Emojis, ícones e Nerd Fonts no terminal
#  Debian/Ubuntu, Arch, Fedora, Void, openSUSE e Alpine
# ============================================================

set -euo pipefail

# ------------------------------------------------------------
# Cores e mensagens
# ------------------------------------------------------------
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
[[ -r /etc/os-release ]] || die "Não foi possível detectar a distribuição."
# shellcheck disable=SC1091
. /etc/os-release
DISTRO="${ID:-unknown}"
DISTRO_NAME="${PRETTY_NAME:-${NAME:-$DISTRO}}"

if [[ $EUID -eq 0 ]]; then
    die "Execute como usuário normal (sem sudo). O script usa sudo apenas para instalar pacotes."
fi

command -v sudo >/dev/null 2>&1 || die "sudo não encontrado."

info "Distribuição detectada: $DISTRO_NAME"

# ------------------------------------------------------------
# Pacotes de fontes
# ------------------------------------------------------------
install_fonts() {
    case "$DISTRO" in
        debian|ubuntu|linuxmint|zorin|pop|kali|raspbian)
            sudo apt-get update -y
            sudo apt-get install -y \
                fontconfig fonts-noto fonts-noto-color-emoji \
                fonts-symbola fonts-powerline fonts-firacode \
                unzip curl
            ;;
        arch|manjaro|endeavouros|arco)
            sudo pacman -Syu --noconfirm
            sudo pacman -S --needed --noconfirm \
                fontconfig noto-fonts noto-fonts-emoji \
                ttf-dejavu ttf-fira-code unzip curl
            ;;
        fedora)
            sudo dnf install -y \
                fontconfig google-noto-emoji-fonts fira-code-fonts \
                dejavu-sans-fonts unzip curl
            ;;
        void)
            sudo xbps-install -Suy
            sudo xbps-install -y \
                fontconfig noto-fonts-emoji dejavu-fonts-ttf \
                font-fira-code unzip curl
            ;;
        opensuse*|suse)
            sudo zypper --non-interactive refresh
            sudo zypper --non-interactive install --auto-agree-with-licenses \
                fontconfig noto-coloremoji-fonts fira-code-fonts \
                dejavu-fonts unzip curl
            ;;
        alpine)
            sudo apk add --no-cache \
                fontconfig font-noto font-noto-emoji font-dejavu \
                unzip curl
            ;;
        *)
            warn "Distribuição não reconhecida. Tentando continuar com as ferramentas disponíveis."
            ;;
    esac
}

info "Instalando pacotes de fontes..."
install_fonts

for cmd in curl unzip fc-cache; do
    command -v "$cmd" >/dev/null 2>&1 \
        || die "O comando '$cmd' não está disponível. Instale-o e rode novamente."
done

# ------------------------------------------------------------
# FiraCode Nerd Font (usuário)
# ------------------------------------------------------------
FONT_DIR="$HOME/.local/share/fonts"
TARGET_DIR="$FONT_DIR/FiraCode"
mkdir -p "$TARGET_DIR"

if find "$TARGET_DIR" -type f -name '*.ttf' -print -quit 2>/dev/null | grep -q .; then
    ok "FiraCode Nerd Font já está instalada."
else
    info "Baixando FiraCode Nerd Font..."
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT

    url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
    curl -fL --retry 3 --connect-timeout 15 -o "$tmp_dir/FiraCode.zip" "$url" \
        || die "Falha ao baixar a fonte. Verifique sua conexão."

    info "Extraindo..."
    unzip -q -o "$tmp_dir/FiraCode.zip" -d "$TARGET_DIR"
    rm -rf "$tmp_dir"
    ok "Fonte instalada em $TARGET_DIR"
fi

# ------------------------------------------------------------
# Cache de fontes
# ------------------------------------------------------------
info "Atualizando o cache de fontes..."
fc-cache -f >/dev/null

if command -v fc-list >/dev/null 2>&1 && fc-list 2>/dev/null | grep -qi "FiraCode Nerd"; then
    ok "FiraCode Nerd Font reconhecida pelo fontconfig."
else
    warn "A fonte foi instalada, mas ainda não aparece no fc-list. Reinicie o terminal."
fi

printf '\n'
ok "Ícones e fontes configurados!"
info "No terminal, selecione uma fonte Nerd Font (ex.: FiraCode Nerd Font) nas preferências."
