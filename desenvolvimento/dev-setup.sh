#!/usr/bin/env bash
# ============================================================
#  Ambiente completo de desenvolvimento
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

install_flatpak() {
    command -v flatpak >/dev/null 2>&1 && return 0

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
        *)
            warn "Distro não reconhecida para instalar o Flatpak."
            return 1
            ;;
    esac

    command -v flatpak >/dev/null 2>&1
}

install_vscode() {
    case "$DISTRO" in
        debian|ubuntu|linuxmint|zorin|pop)
            info "Instalando VS Code (repositório oficial)..."
            curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
                | gpg --dearmor \
                | $SUDO tee /usr/share/keyrings/packages.microsoft.gpg >/dev/null
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
                | $SUDO tee /etc/apt/sources.list.d/vscode.list >/dev/null
            $SUDO apt-get update -y
            $SUDO apt-get install -y code || warn "Não foi possível instalar o VS Code."
            ;;
        fedora)
            info "Instalando VS Code (repositório oficial)..."
            $SUDO rpm --import https://packages.microsoft.com/keys/microsoft.asc || true
            $SUDO tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
            $SUDO dnf install -y code || warn "Não foi possível instalar o VS Code."
            ;;
        arch|manjaro|endeavouros|arco)
            $SUDO pacman -S --needed --noconfirm code || warn "Não foi possível instalar o VS Code."
            ;;
        void)
            if install_flatpak; then
                if flatpak remote-add "$FLATPAK_SCOPE" --if-not-exists flathub \
                    https://flathub.org/repo/flathub.flatpakrepo; then
                    flatpak install "$FLATPAK_SCOPE" -y flathub com.visualstudio.code \
                        || warn "Não foi possível instalar o VS Code via Flatpak."
                else
                    warn "Não foi possível adicionar o repositório Flathub."
                fi
            else
                warn "Flatpak indisponível; instale o VS Code manualmente."
            fi
            ;;
        opensuse*|suse)
            info "Instalando VS Code (repositório oficial)..."
            $SUDO rpm --import https://packages.microsoft.com/keys/microsoft.asc || true
            $SUDO tee /etc/zypp/repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
            $SUDO zypper --non-interactive install code || warn "Não foi possível instalar o VS Code."
            ;;
    esac
}

# ------------------------------------------------------------
# Instalação por distribuição
# ------------------------------------------------------------
case "$DISTRO" in
    debian|ubuntu|linuxmint|zorin|pop)
        install_pkgs apt \
            curl wget git build-essential software-properties-common \
            gnupg ca-certificates apt-transport-https \
            vim neovim python3 python3-pip python3-venv \
            nodejs npm openjdk-17-jdk \
            gcc g++ clang rustc cargo golang php \
            default-mysql-client sqlite3 lua5.4 \
            unzip ripgrep fd-find make cmake pkg-config \
            || warn "Alguns pacotes nativos não puderam ser instalados."
        install_vscode
        ;;
    fedora)
        install_pkgs dnf \
            curl wget git vim neovim python3 python3-pip \
            nodejs npm java-17-openjdk \
            gcc gcc-c++ clang rust cargo golang php sqlite \
            ripgrep fd-find unzip make cmake pkgconf-pkg-config \
            || warn "Alguns pacotes nativos não puderam ser instalados."
        install_vscode
        ;;
    arch|manjaro|endeavouros|arco)
        install_pkgs pacman \
            curl wget git vim neovim python python-pip \
            nodejs npm jdk-openjdk \
            gcc clang rust go php sqlite \
            ripgrep fd unzip make cmake pkgconf \
            || warn "Alguns pacotes nativos não puderam ser instalados."
        install_vscode
        ;;
    void)
        install_pkgs xbps \
            curl wget git vim neovim python3 python3-pip \
            nodejs npm openjdk17 \
            gcc clang rust cargo go php sqlite \
            ripgrep fd unzip make cmake pkg-config \
            || warn "Alguns pacotes nativos não puderam ser instalados."
        install_vscode
        ;;
    opensuse*|suse)
        install_pkgs zypper \
            curl wget git vim neovim python3 python3-pip \
            nodejs npm java-17-openjdk-devel \
            gcc gcc-c++ clang rust cargo go php sqlite3 \
            ripgrep fd unzip make cmake pkg-config \
            || warn "Alguns pacotes nativos não puderam ser instalados."
        install_vscode
        ;;
    *)
        warn "Distribuição não reconhecida."
        warn "Instale manualmente: git, vim/neovim, Python, Node.js, Java, compiladores e VS Code."
        ;;
esac

printf '\n'
ok "Ambiente de desenvolvimento configurado!"
info "Abra um novo terminal para carregar todas as ferramentas."
