#!/usr/bin/env bash
# ============================================================
#  Setup completo do Hyprland no Arch Linux
#  Hyprland + Waybar + Rofi + Alacritty + SDDM
# ============================================================

set -euo pipefail

if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_DIM=$'\033[2m'
else
    C_RESET="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_DIM=""
fi

info() { printf '%sℹ️  %s%s\n' "$C_BLUE" "$*" "$C_RESET"; }
ok()   { printf '%s✅ %s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
warn() { printf '%s⚠️  %s%s\n' "$C_YELLOW" "$*" "$C_RESET"; }
die()  { printf '%s❌ %s%s\n' "$C_RED" "$*" "$C_RESET" >&2; exit 1; }

# ------------------------------------------------------------
# Verificações
# ------------------------------------------------------------
command -v pacman >/dev/null 2>&1 || die "Este script é exclusivo para Arch Linux e derivados."

if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}" in
        arch|endeavouros|manjaro|garuda|arcolinux) ;;
        *) warn "Distribuição '${ID:-desconhecida}' não é Arch oficial. Continuando mesmo assim." ;;
    esac
fi

if [[ $EUID -eq 0 ]]; then
    die "Execute como usuário normal (sem sudo). O makepkg não funciona como root."
fi

command -v sudo >/dev/null 2>&1 || die "sudo não encontrado."

# ------------------------------------------------------------
# Pacotes
# ------------------------------------------------------------
BASE_PKGS=(
    base-devel git curl wget unzip
    neovim nano htop btop fastfetch
    networkmanager network-manager-applet
    bluez bluez-utils
    pipewire wireplumber pipewire-pulse
    xdg-user-dirs xdg-utils
    polkit-kde-agent pavucontrol
    noto-fonts noto-fonts-emoji ttf-dejavu ttf-liberation
    ttf-jetbrains-mono-nerd
    bash-completion
)

HYPR_PKGS=(
    hyprland waybar alacritty rofi-wayland dunst thunar
    grim slurp wl-clipboard
    qt5-wayland qt6-wayland
    xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-hyprland
)

info "Atualizando o sistema..."
sudo pacman -Syu --noconfirm

info "Instalando pacotes base..."
sudo pacman -S --needed --noconfirm "${BASE_PKGS[@]}"

info "Ativando serviços..."
sudo systemctl enable NetworkManager.service 2>/dev/null || warn "Não foi possível ativar o NetworkManager."
sudo systemctl enable bluetooth.service 2>/dev/null || warn "Não foi possível ativar o Bluetooth."

# ------------------------------------------------------------
# yay
# ------------------------------------------------------------
if ! command -v yay >/dev/null 2>&1; then
    info "Instalando yay..."
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT
    git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp_dir/yay"
    ( cd "$tmp_dir/yay" && makepkg -si --noconfirm )
else
    ok "yay já está instalado."
fi

# ------------------------------------------------------------
# Hyprland e SDDM
# ------------------------------------------------------------
info "Instalando Hyprland e componentes..."
sudo pacman -S --needed --noconfirm "${HYPR_PKGS[@]}"

info "Instalando SDDM..."
sudo pacman -S --needed --noconfirm sddm
sudo systemctl enable sddm.service 2>/dev/null || warn "Não foi possível ativar o SDDM."

if [[ -d /usr/share/sddm/themes/breeze ]]; then
    sudo mkdir -p /etc/sddm.conf.d
    printf '[Theme]\nCurrent=breeze\n' | sudo tee /etc/sddm.conf.d/theme.conf >/dev/null
else
    warn "Tema 'breeze' do SDDM não encontrado. Mantendo o tema padrão."
fi

xdg-user-dirs-update 2>/dev/null || true

# ------------------------------------------------------------
# Configurações do usuário
# ------------------------------------------------------------
backup_file() {
    local file="$1"
    [[ -e "$file" ]] || return 0
    local backup
    backup="${file}.bak.$(date +%Y%m%d-%H%M%S)"
    cp -a "$file" "$backup"
    info "Backup criado: $backup"
}

mkdir -p "$HOME/.config/hypr"
backup_file "$HOME/.config/hypr/hyprland.conf"

info "Escrevendo configuração do Hyprland..."
cat > "$HOME/.config/hypr/hyprland.conf" <<'EOF'
monitor=,preferred,auto,1

exec-once = waybar
exec-once = dunst
exec-once = nm-applet
exec-once = /usr/lib/polkit-kde-authentication-agent-1

$mod = SUPER
$terminal = alacritty
$menu = rofi -show drun

input {
    kb_layout = br
    follow_mouse = 1
    touchpad {
        natural_scroll = true
    }
}

# -------- ATALHOS --------
bind = $mod, RETURN, exec, $terminal
bind = $mod, D, exec, $menu
bind = $mod, R, exec, rofi -show run
bind = $mod, Q, killactive
bind = $mod, E, exec, thunar
bind = $mod, V, togglefloating
bind = $mod, F, fullscreen
bind = $mod, TAB, cyclenext

# Navegação estilo Vim
bind = $mod, H, movefocus, l
bind = $mod, L, movefocus, r
bind = $mod, K, movefocus, u
bind = $mod, J, movefocus, d

bind = $mod SHIFT, H, movewindow, l
bind = $mod SHIFT, L, movewindow, r
bind = $mod SHIFT, K, movewindow, u
bind = $mod SHIFT, J, movewindow, d

# Workspaces
bind = $mod, 1, workspace, 1
bind = $mod, 2, workspace, 2
bind = $mod, 3, workspace, 3
bind = $mod, 4, workspace, 4
bind = $mod, 5, workspace, 5

bind = $mod SHIFT, 1, movetoworkspace, 1
bind = $mod SHIFT, 2, movetoworkspace, 2
bind = $mod SHIFT, 3, movetoworkspace, 3
bind = $mod SHIFT, 4, movetoworkspace, 4
bind = $mod SHIFT, 5, movetoworkspace, 5

# Captura de tela
bind = $mod SHIFT, S, exec, grim -g "$(slurp)" - | wl-copy

# -------- VISUAL --------
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(89b4faff)
    col.inactive_border = rgba(45475aff)
}

decoration {
    rounding = 8
    blur {
        enabled = true
        size = 5
        passes = 2
    }
}

animations {
    enabled = yes
    bezier = ease, 0.25, 0.1, 0.25, 1.0
    animation = windows, 1, 7, ease
    animation = fade, 1, 7, ease
    animation = workspaces, 1, 6, ease
}
EOF

# ------------------------------------------------------------
# Waybar
# ------------------------------------------------------------
mkdir -p "$HOME/.config/waybar"
backup_file "$HOME/.config/waybar/config"
backup_file "$HOME/.config/waybar/config.jsonc"
backup_file "$HOME/.config/waybar/style.css"
# Evita que o Waybar leia a configuração antiga no formato antigo
rm -f "$HOME/.config/waybar/config"

info "Escrevendo configuração do Waybar..."
cat > "$HOME/.config/waybar/config.jsonc" <<'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 34,
    "spacing": 6,
    "modules-left": ["hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["network", "pulseaudio", "battery"],

    "hyprland/workspaces": {
        "format": "{name}",
        "on-click": "activate"
    },
    "clock": {
        "format": "{:%H:%M  %d/%m}",
        "tooltip-format": "{:%A, %d de %B de %Y}"
    },
    "network": {
        "format-wifi": "  {essid}",
        "format-ethernet": "󰈀 {ifname}",
        "format-disconnected": "󰤮 offline",
        "tooltip-format": "{ifname} via {gwaddr}"
    },
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "󰖁 mudo",
        "format-icons": ["󰕿", "󰖀", "󰕾"],
        "on-click": "pavucontrol"
    },
    "battery": {
        "format": "{icon} {capacity}%",
        "format-icons": ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    }
}
EOF

cat > "$HOME/.config/waybar/style.css" <<'EOF'
* {
    font-family: "JetBrainsMono Nerd Font", "Noto Sans", sans-serif;
    font-size: 13px;
    border: none;
    border-radius: 0;
}

window#waybar {
    background: rgba(30, 30, 46, 0.92);
    color: #cdd6f4;
    border-radius: 0 0 12px 12px;
}

#workspaces button {
    padding: 0 8px;
    color: #a6adc8;
    background: transparent;
}

#workspaces button.active {
    color: #89b4fa;
    box-shadow: inset 0 -2px #89b4fa;
}

#clock,
#network,
#pulseaudio,
#battery {
    padding: 0 10px;
    color: #cdd6f4;
}

#battery.warning {
    color: #f9e2af;
}

#battery.critical {
    color: #f38ba8;
}
EOF

# ------------------------------------------------------------
# Fastfetch
# ------------------------------------------------------------
mkdir -p "$HOME/.config/fastfetch"
backup_file "$HOME/.config/fastfetch/config.jsonc"

cat > "$HOME/.config/fastfetch/config.jsonc" <<'EOF'
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        "type": "auto"
    },
    "display": {
        "separator": "  "
    },
    "modules": [
        "title",
        "separator",
        "os",
        "kernel",
        "uptime",
        "packages",
        "shell",
        "wm",
        "de",
        "cpu",
        "gpu",
        "memory",
        "disk",
        "break",
        "colors"
    ]
}
EOF

# ------------------------------------------------------------
# Final
# ------------------------------------------------------------
printf '\n'
ok "Setup do Hyprland finalizado!"
printf '  %sReinicie o sistema e escolha Hyprland no SDDM.%s\n' "$C_YELLOW" "$C_RESET"
printf '  %sAtalhos:%s SUPER+ENTER terminal · SUPER+D menu · SUPER+Q fechar\n' "$C_DIM" "$C_RESET"
printf '  %sLayout do teclado:%s br (edite ~/.config/hypr/hyprland.conf se necessário)\n' "$C_DIM" "$C_RESET"
