#!/usr/bin/env bash
# ============================================================
#  Bluetooth + PulseAudio no Void Linux
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
command -v xbps-install >/dev/null 2>&1 || die "Este script é exclusivo para Void Linux."

if [[ $EUID -eq 0 ]]; then
    die "Execute como usuário normal (sem sudo). O script usa sudo quando necessário."
fi

command -v sudo >/dev/null 2>&1 || die "sudo não encontrado."

# ------------------------------------------------------------
# Instalação
# ------------------------------------------------------------
info "Atualizando os repositórios..."
sudo xbps-install -Suy

info "Instalando PulseAudio e suporte a Bluetooth..."
sudo xbps-install -y pulseaudio pulseaudio-utils pulseaudio-bluetooth

info "Instalando bluez..."
sudo xbps-install -y bluez bluez-tools

command -v pulseaudio >/dev/null 2>&1 || die "PulseAudio não foi encontrado após a instalação."
command -v bluetoothctl >/dev/null 2>&1 || die "bluetoothctl não foi encontrado após a instalação."

# ------------------------------------------------------------
# Serviços runit
# ------------------------------------------------------------
if [[ -e /etc/sv/dbus ]]; then
    info "Ativando D-Bus..."
    sudo ln -sfn /etc/sv/dbus /var/service/
    sudo sv restart dbus 2>/dev/null || sudo sv start dbus 2>/dev/null || true
fi

[[ -e /etc/sv/bluetoothd ]] || die "Serviço /etc/sv/bluetoothd não encontrado."

info "Ativando o serviço Bluetooth..."
sudo ln -sfn /etc/sv/bluetoothd /var/service/
sudo sv restart bluetoothd 2>/dev/null || sudo sv start bluetoothd 2>/dev/null || true

if command -v rfkill >/dev/null 2>&1; then
    sudo rfkill unblock bluetooth 2>/dev/null || true
fi

# ------------------------------------------------------------
# PulseAudio
# ------------------------------------------------------------
info "Reiniciando o PulseAudio..."
if pulseaudio --check >/dev/null 2>&1; then
    pulseaudio -k >/dev/null 2>&1 || true
fi
pulseaudio --start >/dev/null 2>&1 || warn "Não foi possível iniciar o PulseAudio agora."

# ------------------------------------------------------------
# Resumo
# ------------------------------------------------------------
printf '\n'
if sudo sv status bluetoothd 2>/dev/null | grep -q '^run:'; then
    ok "Bluetooth ativo."
else
    warn "O serviço bluetoothd não parece estar ativo. Verifique: sudo sv status bluetoothd"
fi

ok "Bluetooth + PulseAudio configurados!"
printf '  %sParear dispositivo:%s bluetoothctl\n' "$C_YELLOW" "$C_RESET"
printf '  %sReiniciar áudio:%s    pulseaudio -k && pulseaudio --start\n' "$C_YELLOW" "$C_RESET"
