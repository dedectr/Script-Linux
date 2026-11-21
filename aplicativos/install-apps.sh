#!/usr/bin/env bash
# ============================================================
#  Instalador universal de aplicativos essenciais (sem Snap)
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
# Instalação de pacotes com fallback individual
# ------------------------------------------------------------
install_pkgs() {
    local pm="$1"
    shift
    local -a pkgs=("$@")
    local p failed=0

    ((${#pkgs[@]})) || return 0

    case "$pm" in
        apt)
            $SUDO apt-get update -y
            if ! $SUDO apt-get install -y "${pkgs[@]}"; then
                warn "Alguns pacotes falharam. Tentando instalar um por um..."
                for p in "${pkgs[@]}"; do
                    $SUDO apt-get install -y "$p" || { warn "Não encontrado: $p"; failed=1; }
                done
            fi
            ;;
        dnf)
            if ! $SUDO dnf install -y "${pkgs[@]}"; then
                warn "Alguns pacotes falharam. Tentando instalar um por um..."
                for p in "${pkgs[@]}"; do
                    $SUDO dnf install -y "$p" || { warn "Não encontrado: $p"; failed=1; }
                done
            fi
            ;;
        pacman)
            $SUDO pacman -Syu --noconfirm
            if ! $SUDO pacman -S --needed --noconfirm "${pkgs[@]}"; then
                warn "Alguns pacotes falharam. Tentando instalar um por um..."
                for p in "${pkgs[@]}"; do
                    $SUDO pacman -S --needed --noconfirm "$p" || { warn "Não encontrado: $p"; failed=1; }
                done
            fi
            ;;
        xbps)
            $SUDO xbps-install -Suy
            if ! $SUDO xbps-install -y "${pkgs[@]}"; then
                warn "Alguns pacotes falharam. Tentando instalar um por um..."
                for p in "${pkgs[@]}"; do
                    $SUDO xbps-install -y "$p" || { warn "Não encontrado: $p"; failed=1; }
                done
            fi
            ;;
        zypper)
            $SUDO zypper --non-interactive refresh
            if ! $SUDO zypper --non-interactive install --auto-agree-with-licenses "${pkgs[@]}"; then
                warn "Alguns pacotes falharam. Tentando instalar um por um..."
                for p in "${pkgs[@]}"; do
                    $SUDO zypper --non-interactive install --auto-agree-with-licenses "$p" \
                        || { warn "Não encontrado: $p"; failed=1; }
                done
            fi
            ;;
        *)
            return 1
            ;;
    esac

    return "$failed"
}

# ------------------------------------------------------------
# Flatpak + Flathub
# ------------------------------------------------------------
install_flatpak() {
    if ! command -v flatpak >/dev/null 2>&1; then
        info "Instalando Flatpak..."
        case "$DISTRO" in
            debian|ubuntu|linuxmint|zorin|pop)
                $SUDO apt-get update -y && $SUDO apt-get install -y flatpak
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
    fi

    command -v flatpak >/dev/null 2>&1 || return 1

    info "Garantindo o repositório Flathub..."
    if ! flatpak remote-add "$FLATPAK_SCOPE" --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo; then
        warn "Não foi possível adicionar o repositório Flathub."
        return 1
    fi
}

install_flatpak_apps() {
    local app
    for app in "$@"; do
        info "Instalando $app via Flatpak..."
        if flatpak install "$FLATPAK_SCOPE" -y flathub "$app"; then
            ok "Flatpak: $app"
        else
            warn "Não foi possível instalar $app via Flatpak."
        fi
    done
}

# ------------------------------------------------------------
# Instalação por distribuição
# ------------------------------------------------------------
case "$DISTRO" in
    debian|ubuntu|linuxmint|zorin|pop)
        install_pkgs apt \
            wget curl git flatpak gnome-software-plugin-flatpak \
            wine64 winetricks lutris \
            kdenlive shotcut gimp audacity obs-studio vlc \
            || warn "Alguns pacotes nativos não puderam ser instalados."
        install_flatpak || warn "Flatpak indisponível; apps extras serão ignorados."
        install_flatpak_apps us.zoom.Zoom
        ;;
    fedora)
        install_pkgs dnf \
            wget curl git flatpak wine winetricks lutris \
            kdenlive shotcut gimp audacity obs-studio vlc \
            || warn "Alguns pacotes nativos não puderam ser instalados."
        install_flatpak || warn "Flatpak indisponível; apps extras serão ignorados."
        install_flatpak_apps us.zoom.Zoom
        ;;
    arch|manjaro|endeavouros|arco)
        install_pkgs pacman \
            wget curl git flatpak wine winetricks lutris \
            kdenlive shotcut gimp audacity obs-studio vlc \
            || warn "Alguns pacotes nativos não puderam ser instalados."
        install_flatpak || warn "Flatpak indisponível; apps extras serão ignorados."
        install_flatpak_apps us.zoom.Zoom
        ;;
    void)
        install_pkgs xbps \
            wget curl git flatpak wine winetricks lutris \
            kdenlive shotcut gimp audacity obs vlc \
            || warn "Alguns pacotes nativos não puderam ser instalados."
        install_flatpak || warn "Flatpak indisponível; apps extras serão ignorados."
        install_flatpak_apps us.zoom.Zoom
        ;;
    opensuse*|suse)
        install_pkgs zypper \
            wget curl git flatpak wine winetricks lutris \
            kdenlive shotcut gimp audacity obs-studio vlc \
            || warn "Alguns pacotes nativos não puderam ser instalados."
        install_flatpak || warn "Flatpak indisponível; apps extras serão ignorados."
        install_flatpak_apps us.zoom.Zoom
        ;;
    *)
        warn "Distribuição não reconhecida. Instalando os aplicativos via Flatpak..."
        install_flatpak || die "Não foi possível instalar o Flatpak nesta distribuição."
        install_flatpak_apps \
            com.obsproject.Studio \
            org.kde.kdenlive \
            org.shotcut.Shotcut \
            org.gimp.GIMP \
            org.audacityteam.Audacity \
            org.videolan.VLC \
            net.lutris.Lutris \
            us.zoom.Zoom
        ;;
esac

printf '\n'
ok "Instalação finalizada!"
info "Dica: reinicie a sessão para os ícones aparecerem no menu."
