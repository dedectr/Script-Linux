#!/usr/bin/env bash
# ============================================================
#  Script-Linux — Menu interativo
#  Execute: ./menu.sh
# ============================================================

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------------------------------------
# Cores (apenas quando a saída é um terminal)
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

info()  { printf '%sℹ️  %s%s\n' "$C_BLUE" "$*" "$C_RESET"; }
ok()    { printf '%s✅ %s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
warn()  { printf '%s⚠️  %s%s\n' "$C_YELLOW" "$*" "$C_RESET"; }
err()   { printf '%s❌ %s%s\n' "$C_RED" "$*" "$C_RESET" >&2; }

clear_screen() { if [[ -t 1 ]]; then clear; fi; }

pause() {
    printf '\n%sPressione ENTER para continuar...%s' "$C_DIM" "$C_RESET"
    read -r _ || true
}

# ------------------------------------------------------------
# Distribuição atual
# ------------------------------------------------------------
DISTRO_NAME="Linux"
if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_NAME="${PRETTY_NAME:-${NAME:-Linux}}"
fi

# ------------------------------------------------------------
# Metadados dos scripts
# formato: categoria|arquivo|nome|descrição|precisa_root(1)
# ------------------------------------------------------------
SCRIPTS=(
    "aplicativos|install-apps.sh|Instalar apps essenciais|OBS, Kdenlive, GIMP, Audacity, VLC, Wine, Lutris e Flatpak.|"
    "aplicativos|install-flatpak-apps.sh|Apps de produtividade (Flatpak)|Menu com multiseleção: comunicação, escritório, navegadores, mídia, notas e e-mail.|"
    "desenvolvimento|dev-setup.sh|Ambiente de desenvolvimento|Vim, Neovim, VS Code, Python, C/C++, Java, Rust, Go, JS, PHP e SQL.|"
    "jogos|install-games.sh|Instalar jogos e launchers|Steam, Heroic, Lutris, Itch.io, RetroArch, Bottles, ProtonUp-Qt e MangoHUD.|"
    "jogos|minecraft-server.sh|Servidor de Minecraft|Menu para instalar, iniciar, parar, reiniciar, console, status e backup.|"
    "rede|auto-config-rede.sh|Configurar rede automaticamente|Ativa as interfaces físicas e solicita IP via DHCP.|1"
    "rede|install-hamachi-arch.sh|Instalar Hamachi (Arch)|Instala e configura o Hamachi no Arch Linux via AUR.|"
    "rede|install-hamachi-void.sh|Instalar Hamachi (Void)|Instala o Hamachi no Void Linux a partir do pacote oficial.|"
    "rede|install-openvpn.sh|Configurar servidor OpenVPN|Cria o servidor, certificados e menu para gerenciar clientes.|1"
    "rede|install-zerotier.sh|Compilar e instalar ZeroTier|Compila o ZeroTier com suporte a systemd, OpenRC e runit.|1"
    "servidor|create-superuser.sh|Criar superusuário|Cria um usuário com sudo, shell e senha personalizados.|"
    "sistema|icons-terminal.sh|Ícones e fontes no terminal|Instala emojis, ícones, Powerline e Nerd Fonts.|"
    "sistema|install-bluetooth-pulse.sh|Bluetooth + PulseAudio (Void)|Instala e ativa Bluetooth e PulseAudio no Void Linux.|"
    "sistema|install-hyprland-arch.sh|Setup completo do Hyprland|Hyprland, Waybar, Rofi, Alacritty, SDDM e configs prontas.|"
    "sistema|yay.sh|Instalar yay (AUR)|Instala o AUR helper yay no Arch Linux.|"
)

CATEGORY_KEYS=(aplicativos desenvolvimento jogos rede servidor sistema)
CATEGORY_LABELS=(
    "🖥️  Aplicativos"
    "💻 Desenvolvimento"
    "🎮 Jogos"
    "🌐 Rede e VPN"
    "🖧  Servidor"
    "⚙️  Sistema"
)

category_count() {
    local key="$1" entry cat count=0
    for entry in "${SCRIPTS[@]}"; do
        IFS='|' read -r cat _ _ _ _ <<< "$entry"
        [[ "$cat" == "$key" ]] && count=$((count + 1))
    done
    printf '%d' "$count"
}

# ------------------------------------------------------------
# Execução de um script
# ------------------------------------------------------------
run_script() {
    local file="$1" name="$2" desc="$3" need_root="${4:-}"
    local script="$ROOT/$file"

    clear_screen
    printf '%s╭──────────────────────────────────────────────────────────────╮%s\n' "$C_BLUE" "$C_RESET"
    printf '  %s%s%s\n' "$C_BOLD$C_CYAN" "$name" "$C_RESET"
    printf '%s╰──────────────────────────────────────────────────────────────╯%s\n' "$C_BLUE" "$C_RESET"
    printf '\n  %s\n\n' "$desc"
    printf '  %sArquivo:%s %s\n' "$C_DIM" "$C_RESET" "$file"
    [[ "$need_root" == "1" ]] && printf '  %sRequer:%s root (sudo)\n' "$C_DIM" "$C_RESET"
    printf '\n'

    if [[ ! -f "$script" ]]; then
        err "Script não encontrado: $script"
        pause
        return 0
    fi

    local answer
    read -rp "Executar agora? [S/n]: " answer || return 0
    case "${answer,,}" in
        n|nao|não) return 0 ;;
    esac

    # Detecta o interpretador pelo shebang
    local shebang interpreter
    shebang="$(head -n 1 "$script")"
    if [[ "$shebang" == *bash* ]]; then
        interpreter="bash"
    else
        interpreter="sh"
    fi

    local -a cmd
    if [[ "$need_root" == "1" && $EUID -ne 0 ]]; then
        if ! command -v sudo >/dev/null 2>&1; then
            err "sudo não encontrado. Execute este script como root."
            pause
            return 0
        fi
        cmd=(sudo "$interpreter" "$script")
    else
        cmd=("$interpreter" "$script")
    fi

    printf '\n%s▶ Executando %s...%s\n\n' "$C_CYAN" "$file" "$C_RESET"
    local rc=0
    "${cmd[@]}" || rc=$?

    printf '\n'
    if [[ $rc -eq 0 ]]; then
        ok "Script concluído com sucesso."
    else
        err "O script terminou com erro (código $rc)."
    fi
    pause
}

# ------------------------------------------------------------
# Menu de uma categoria
# ------------------------------------------------------------
category_menu() {
    local key="$1" label="$2"
    local -a entries=()
    local entry cat file name desc need_root

    for entry in "${SCRIPTS[@]}"; do
        IFS='|' read -r cat _ _ _ _ <<< "$entry"
        [[ "$cat" == "$key" ]] && entries+=("$entry")
    done

    while true; do
        clear_screen
        printf '%s╭──────────────────────────────────────────────────────────────╮%s\n' "$C_BLUE" "$C_RESET"
        printf '  %s%s%s\n' "$C_BOLD$C_MAGENTA" "$label" "$C_RESET"
        printf '%s╰──────────────────────────────────────────────────────────────╯%s\n' "$C_BLUE" "$C_RESET"
        printf '\n'

        local i
        for i in "${!entries[@]}"; do
            IFS='|' read -r _ file name desc need_root <<< "${entries[$i]}"
            printf '  %s[%d]%s %s\n' "$C_YELLOW" "$((i + 1))" "$C_RESET" "$name"
            printf '      %s%s%s\n' "$C_DIM" "$desc" "$C_RESET"
        done

        printf '\n  %s[0]%s ← Voltar\n' "$C_YELLOW" "$C_RESET"
        printf '%s──────────────────────────────────────────────────────────────%s\n' "$C_DIM" "$C_RESET"

        local choice
        read -rp "Escolha uma opção: " choice || return 0

        if [[ "$choice" == "0" ]]; then
            return 0
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#entries[@]} )); then
            IFS='|' read -r _ file name desc need_root <<< "${entries[$((choice - 1))]}"
            run_script "$file" "$name" "$desc" "$need_root"
        else
            warn "Opção inválida: $choice"
            sleep 1
        fi
    done
}

# ------------------------------------------------------------
# Ações extras
# ------------------------------------------------------------
open_readme() {
    clear_screen
    if [[ ! -f "$ROOT/README.md" ]]; then
        err "README.md não encontrado."
        pause
        return 0
    fi
    if command -v less >/dev/null 2>&1; then
        less "$ROOT/README.md"
    else
        cat "$ROOT/README.md"
    fi
    pause
}

update_repo() {
    clear_screen
    printf '%s╭──────────────────────────────────────────────────────────────╮%s\n' "$C_BLUE" "$C_RESET"
    printf '  %s🔄 Atualizar repositório%s\n' "$C_BOLD$C_CYAN" "$C_RESET"
    printf '%s╰──────────────────────────────────────────────────────────────╯%s\n' "$C_BLUE" "$C_RESET"
    printf '\n'

    if ! command -v git >/dev/null 2>&1; then
        err "git não encontrado."
        pause
        return 0
    fi
    if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        err "Esta pasta não é um repositório git."
        pause
        return 0
    fi

    if git -C "$ROOT" pull --ff-only; then
        ok "Repositório atualizado."
    else
        warn "Não foi possível atualizar. Verifique alterações locais ou conflitos."
    fi
    pause
}

show_help() {
    cat <<EOF
Uso: ./menu.sh [opção]

Opções:
  -h, --help   Mostra esta ajuda
  --list       Lista todos os scripts disponíveis
EOF
}

list_scripts() {
    local entry cat file name desc need_root
    for entry in "${SCRIPTS[@]}"; do
        IFS='|' read -r cat file name desc need_root <<< "$entry"
        printf '%-22s %-32s %s\n' "$cat" "$file" "$name"
    done
}

# ------------------------------------------------------------
# Menu principal
# ------------------------------------------------------------
main_menu() {
    while true; do
        clear_screen
        printf '%s╭──────────────────────────────────────────────────────────────╮%s\n' "$C_BLUE" "$C_RESET"
        printf '  %s🐧  SCRIPT-LINUX%s\n' "$C_BOLD$C_CYAN" "$C_RESET"
        printf '  %s%s%s\n' "$C_DIM" "$DISTRO_NAME" "$C_RESET"
        printf '%s╰──────────────────────────────────────────────────────────────╯%s\n' "$C_BLUE" "$C_RESET"
        printf '\n'

        local i count unit
        for i in "${!CATEGORY_KEYS[@]}"; do
            count="$(category_count "${CATEGORY_KEYS[$i]}")"
            unit="scripts"
            [[ "$count" -eq 1 ]] && unit="script"
            printf '  %s[%d]%s %-24s %s(%d %s)%s\n' \
                "$C_YELLOW" "$((i + 1))" "$C_RESET" \
                "${CATEGORY_LABELS[$i]}" \
                "$C_DIM" "$count" "$unit" "$C_RESET"
        done

        printf '\n'
        printf '  %s[7]%s 📖 Abrir README\n' "$C_YELLOW" "$C_RESET"
        printf '  %s[8]%s 🔄 Atualizar repositório (git pull)\n' "$C_YELLOW" "$C_RESET"
        printf '  %s[0]%s 🚪 Sair\n' "$C_YELLOW" "$C_RESET"
        printf '%s──────────────────────────────────────────────────────────────%s\n' "$C_DIM" "$C_RESET"

        local choice
        read -rp "Escolha uma opção: " choice || exit 0

        case "$choice" in
            0) exit 0 ;;
            7) open_readme ;;
            8) update_repo ;;
            [1-6])
                local idx=$((choice - 1))
                category_menu "${CATEGORY_KEYS[$idx]}" "${CATEGORY_LABELS[$idx]}"
                ;;
            *)
                warn "Opção inválida: $choice"
                sleep 1
                ;;
        esac
    done
}

# ------------------------------------------------------------
# Entrada
# ------------------------------------------------------------
case "${1:-}" in
    -h|--help) show_help; exit 0 ;;
    --list) list_scripts; exit 0 ;;
    "") ;;
    *) err "Opção desconhecida: $1"; show_help; exit 1 ;;
esac

if [[ $EUID -eq 0 ]]; then
    warn "Você está rodando como root. O script sistema/yay.sh deve ser executado como usuário normal."
    sleep 2
fi

main_menu
