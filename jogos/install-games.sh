#!/usr/bin/env bash
# ============================================================
#  Instalador de jogos e launchers via Flatpak
#  Debian/Ubuntu, Arch, Fedora, Void e openSUSE
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
# Distribuição e sudo
# ------------------------------------------------------------
[[ -r /etc/os-release ]] || die "Não foi possível detectar a distribuição."
# shellcheck disable=SC1091
. /etc/os-release
DISTRO="${ID:-unknown}"
DISTRO_NAME="${PRETTY_NAME:-${NAME:-$DISTRO}}"

SUDO=""
if [[ $EUID -ne 0 ]]; then
    command -v sudo >/dev/null 2>&1 || die "sudo não encontrado. Execute como root."
    SUDO="sudo"
fi

if [[ $EUID -eq 0 ]]; then
    FLATPAK_SCOPE="--system"
else
    FLATPAK_SCOPE="--user"
fi

info "Distribuição detectada: $DISTRO_NAME"

# ------------------------------------------------------------
# Flatpak
# ------------------------------------------------------------
install_flatpak() {
    command -v flatpak >/dev/null 2>&1 && return 0

    info "Instalando Flatpak..."
    case "$DISTRO" in
        debian|ubuntu|linuxmint|zorin|pop)
            $SUDO apt-get update -y
            $SUDO apt-get install -y flatpak gnome-software-plugin-flatpak
            ;;
        fedora)
            $SUDO dnf install -y flatpak
            ;;
        arch|manjaro|endeavouros|arco)
            $SUDO pacman -S --needed --noconfirm flatpak
            ;;
        void)
            $SUDO xbps-install -y flatpak
            ;;
        opensuse*|suse)
            $SUDO zypper --non-interactive install flatpak
            ;;
        alpine)
            $SUDO apk add flatpak
            ;;
        *)
            warn "Distro não reconhecida para instalar o Flatpak."
            return 1
            ;;
    esac

    command -v flatpak >/dev/null 2>&1
}

# ------------------------------------------------------------
# Apps
# ------------------------------------------------------------
APPS=(
    "com.valvesoftware.Steam|Steam"
    "com.heroicgameslauncher.hgl|Heroic Games Launcher"
    "net.lutris.Lutris|Lutris"
    "io.itch.itch|Itch.io"
    "org.libretro.RetroArch|RetroArch"
    "com.usebottles.bottles|Bottles"
    "net.davidotek.pupgui2|ProtonUp-Qt"
    "org.freedesktop.Platform.VulkanLayer.MangoHud|MangoHUD"
)

# ------------------------------------------------------------
# Execução
# ------------------------------------------------------------
install_flatpak || die "Não foi possível instalar o Flatpak."

info "Garantindo o repositório Flathub..."
if ! flatpak remote-add "$FLATPAK_SCOPE" --if-not-exists flathub \
    https://flathub.org/repo/flathub.flatpakrepo; then
    die "Não foi possível adicionar o repositório Flathub."
fi

failures=0
for entry in "${APPS[@]}"; do
    IFS='|' read -r app_id app_name <<< "$entry"
    info "Instalando $app_name..."
    if flatpak install "$FLATPAK_SCOPE" -y flathub "$app_id"; then
        ok "$app_name instalado."
    else
        warn "Falha ao instalar $app_name."
        failures=$((failures + 1))
    fi
done

printf '\n'
if [[ $failures -eq 0 ]]; then
    ok "Todos os jogos e launchers foram instalados!"
else
    warn "Instalação concluída com $failures falha(s)."
fi
info "Reinicie a sessão para integrar os ícones ao menu."
