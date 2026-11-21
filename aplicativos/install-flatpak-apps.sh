#!/usr/bin/env bash
# ============================================================
#  Instalador de produtividade via Flatpak
#  Categorias + seleção múltipla
# ============================================================

set -euo pipefail

# ------------------------------------------------------------
# Cores e mensagens
# ------------------------------------------------------------
if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_MAGENTA=$'\033[35m'
    C_CYAN=$'\033[36m'
else
    C_RESET="" C_BOLD="" C_DIM="" C_RED="" C_GREEN=""
    C_YELLOW="" C_BLUE="" C_MAGENTA="" C_CYAN=""
fi

info() { printf '%sℹ️  %s%s\n' "$C_BLUE" "$*" "$C_RESET"; }
ok()   { printf '%s✅ %s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
warn() { printf '%s⚠️  %s%s\n' "$C_YELLOW" "$*" "$C_RESET"; }
err()  { printf '%s❌ %s%s\n' "$C_RED" "$*" "$C_RESET" >&2; }

clear_screen() { if [[ -t 1 ]]; then clear; fi; }
pause() {
    printf '\n%sPressione ENTER para continuar...%s' "$C_DIM" "$C_RESET"
    read -r _ || true
}

# ------------------------------------------------------------
# Distribuição e sudo
# ------------------------------------------------------------
[[ -r /etc/os-release ]] || { err "Não foi possível detectar a distribuição."; exit 1; }
# shellcheck disable=SC1091
. /etc/os-release
DISTRO="${ID:-unknown}"
DISTRO_NAME="${PRETTY_NAME:-${NAME:-$DISTRO}}"

SUDO=""
if [[ $EUID -ne 0 ]]; then
    command -v sudo >/dev/null 2>&1 || { err "sudo não encontrado."; exit 1; }
    SUDO="sudo"
fi

if [[ $EUID -eq 0 ]]; then
    FLATPAK_SCOPE="--system"
else
    FLATPAK_SCOPE="--user"
fi

# ------------------------------------------------------------
# Apps por categoria
# ------------------------------------------------------------
CAT_NAMES=(
    "Comunicação"
    "Escritório"
    "Navegadores"
    "Multimídia"
    "Notas & Organização"
    "E-mail"
)
CAT_IDS=(
    "com.discordapp.Discord org.telegram.desktop com.slack.Slack us.zoom.Zoom"
    "org.onlyoffice.desktopeditors org.libreoffice.LibreOffice"
    "com.brave.Browser org.chromium.Chromium"
    "org.videolan.VLC org.gimp.GIMP org.kde.kdenlive"
    "md.obsidian.Obsidian"
    "org.mozilla.Thunderbird"
)
CAT_LABELS=(
    "Discord Telegram Slack Zoom"
    "OnlyOffice LibreOffice"
    "Brave Chromium"
    "VLC GIMP Kdenlive"
    "Obsidian"
    "Thunderbird"
)

ALL_IDS=()
ALL_NAMES=()
for i in "${!CAT_NAMES[@]}"; do
    read -r -a ids <<< "${CAT_IDS[$i]}"
    read -r -a labels <<< "${CAT_LABELS[$i]}"
    for j in "${!ids[@]}"; do
        ALL_IDS+=("${ids[$j]}")
        ALL_NAMES+=("${labels[$j]}")
    done
done

# ------------------------------------------------------------
# Flatpak
# ------------------------------------------------------------
FLATPAK_READY=0

ensure_flatpak() {
    [[ $FLATPAK_READY -eq 1 ]] && return 0

    if ! command -v flatpak >/dev/null 2>&1; then
        info "Instalando Flatpak..."
        case "$DISTRO" in
            debian|ubuntu|linuxmint|zorin|pop)
                $SUDO apt-get update -y && $SUDO apt-get install -y flatpak
                ;;
            arch|manjaro|endeavouros|arco)
                $SUDO pacman -S --needed --noconfirm flatpak
                ;;
            fedora)
                $SUDO dnf install -y flatpak
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

    FLATPAK_READY=1
}

install_app() {
    local idx="$1"
    ensure_flatpak || { warn "Flatpak indisponível."; return 0; }

    info "Instalando ${ALL_NAMES[$idx]}..."
    if flatpak install "$FLATPAK_SCOPE" -y flathub "${ALL_IDS[$idx]}"; then
        ok "${ALL_NAMES[$idx]} instalado."
    else
        warn "Falha ao instalar ${ALL_NAMES[$idx]}."
    fi
}

install_all() {
    local idx
    for idx in "${!ALL_IDS[@]}"; do
        install_app "$idx"
    done
}

# ------------------------------------------------------------
# Menu
# ------------------------------------------------------------
while true; do
    clear_screen
    printf '%s╭──────────────────────────────────────────────────────────────╮%s\n' "$C_BLUE" "$C_RESET"
    printf '  %s📦 INSTALADOR DE PRODUTIVIDADE (FLATPAK)%s\n' "$C_BOLD$C_CYAN" "$C_RESET"
    printf '  %s%s%s\n' "$C_DIM" "$DISTRO_NAME" "$C_RESET"
    printf '%s╰──────────────────────────────────────────────────────────────╯%s\n' "$C_BLUE" "$C_RESET"
    printf '\n  Escolha um ou mais números: %s1 3 5%s\n\n' "$C_CYAN" "$C_RESET"
    printf '  %s[0]%s Instalar/atualizar Flatpak + Flathub\n' "$C_YELLOW" "$C_RESET"
    printf '  %s[98]%s Instalar todos\n' "$C_YELLOW" "$C_RESET"
    printf '  %s[99]%s Sair\n\n' "$C_YELLOW" "$C_RESET"

    installed_apps=""
    if command -v flatpak >/dev/null 2>&1; then
        installed_apps="$(flatpak list "$FLATPAK_SCOPE" --app --columns=application 2>/dev/null || true)"
    fi

    index=1
    for cat in "${!CAT_NAMES[@]}"; do
        printf '  %s── %s ──%s\n' "$C_MAGENTA" "${CAT_NAMES[$cat]}" "$C_RESET"
        read -r -a ids <<< "${CAT_IDS[$cat]}"
        read -r -a labels <<< "${CAT_LABELS[$cat]}"
        for j in "${!ids[@]}"; do
            mark=""
            if grep -Fqx "${ids[$j]}" <<< "$installed_apps"; then
                mark=" ${C_GREEN}✓${C_RESET}"
            fi
            printf '  %s[%d]%s %s%b\n' "$C_YELLOW" "$index" "$C_RESET" "${labels[$j]}" "$mark"
            index=$((index + 1))
        done
        printf '\n'
    done

    printf '%s──────────────────────────────────────────────────────────────%s\n' "$C_DIM" "$C_RESET"
    read -rp "Opções: " escolha || exit 0

    # Aceita "1,2,3" e "1 2 3"
    escolha="${escolha//,/ }"

    [[ -z "${escolha// /}" ]] && continue
    [[ "$escolha" == "99" ]] && exit 0

    for item in $escolha; do
        if [[ "$item" == "99" ]]; then
            exit 0
        fi
        if [[ "$item" == "0" ]]; then
            if ensure_flatpak; then
                ok "Flatpak e Flathub prontos."
            else
                warn "Não foi possível preparar o Flatpak."
            fi
            continue
        fi
        if [[ "$item" == "98" ]]; then
            install_all
            continue
        fi
        if [[ "$item" =~ ^[0-9]+$ ]] && (( item >= 1 && item <= ${#ALL_IDS[@]} )); then
            install_app "$((item - 1))"
        else
            warn "Opção inválida: $item"
        fi
    done

    pause
done
