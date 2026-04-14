#!/bin/bash

set -e

echo "=============================="
echo " FULL HYPRLAND SETUP (ARCH) "
echo "=============================="

# -----------------------------

# Atualização

# -----------------------------

sudo pacman -Syu --noconfirm

# -----------------------------

# Base + ferramentas

# -----------------------------

sudo pacman -S --needed --noconfirm 
base-devel git curl wget unzip 
neovim nano htop btop fastfetch 
networkmanager network-manager-applet 
bluez bluez-utils 
pipewire wireplumber 
xdg-user-dirs xdg-utils 
polkit-kde-agent 
noto-fonts ttf-dejavu ttf-liberation 
bash-completion

# -----------------------------

# Ativar serviços

# -----------------------------

sudo systemctl enable NetworkManager
sudo systemctl enable bluetooth

# -----------------------------

# Instalar YAY

# -----------------------------

if ! command -v yay &> /dev/null; then
echo "[+] Instalando yay..."
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ..
rm -rf yay
fi

# -----------------------------

# Hyprland + GUI stack

# -----------------------------

sudo pacman -S --needed --noconfirm 
hyprland waybar alacritty rofi-wayland dunst thunar 
grim slurp wl-clipboard 
qt5-wayland qt6-wayland

# -----------------------------

# SDDM (login manager)

# -----------------------------

sudo pacman -S --needed --noconfirm sddm

sudo systemctl enable sddm

# tema simples SDDM

sudo mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=breeze" | sudo tee /etc/sddm.conf.d/theme.conf

# -----------------------------

# Diretórios usuário

# -----------------------------

xdg-user-dirs-update

# -----------------------------

# Config HYPRLAND

# -----------------------------

mkdir -p ~/.config/hypr

cat > ~/.config/hypr/hyprland.conf << 'EOF'

monitor=,preferred,auto,1

exec-once = waybar
exec-once = dunst
exec-once = nm-applet
exec-once = /usr/lib/polkit-kde-authentication-agent-1

$mod = SUPER
$terminal = alacritty
$menu = rofi -show drun

# -------- BINDS --------

bind = $mod, RETURN, exec, $terminal
bind = $mod, D, exec, $menu
bind = $mod, Q, killactive
bind = $mod, E, exec, thunar

# VIM NAV

bind = $mod, H, movefocus, l
bind = $mod, L, movefocus, r
bind = $mod, K, movefocus, u
bind = $mod, J, movefocus, d

# mover

bind = $mod SHIFT, H, movewindow, l
bind = $mod SHIFT, L, movewindow, r
bind = $mod SHIFT, K, movewindow, u
bind = $mod SHIFT, J, movewindow, d

# workspace

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

# extras

bind = $mod, F, fullscreen
bind = $mod SHIFT, S, exec, grim -g "$(slurp)" - | wl-copy

# -------- VISUAL --------

general {
gaps_in = 5
gaps_out = 10
border_size = 2
col.active_border = rgba(88c0d0ff)
col.inactive_border = rgba(2e3440ff)
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

```
animation = windows, 1, 7, ease
animation = fade, 1, 7, ease
```

}

EOF

# -----------------------------

# Waybar config básica

# -----------------------------

mkdir -p ~/.config/waybar

cat > ~/.config/waybar/config << 'EOF'
{
"layer": "top",
"position": "top",
"modules-left": ["hyprland/workspaces"],
"modules-center": ["clock"],
"modules-right": ["network", "pulseaudio", "battery"]
}
EOF

# -----------------------------

# Fastfetch config

# -----------------------------

mkdir -p ~/.config/fastfetch

echo '{
"logo": { "type": "auto" }
}' > ~/.config/fastfetch/config.jsonc

# -----------------------------

# Final

# -----------------------------

echo ""
echo "=============================="
echo " SETUP COMPLETO FINALIZADO ✅"
echo "=============================="
echo ""
echo "👉 Reinicie o sistema"
echo "👉 Escolha Hyprland no SDDM"
echo "👉 SUPER + ENTER (terminal)"
echo "👉 SUPER + D (menu)"
echo ""
echo "🔥 Sistema pronto pra uso!"
