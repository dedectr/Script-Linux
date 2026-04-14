#!/bin/bash

set -e

echo "📦 Atualizando sistema..."
sudo pacman -Syu --noconfirm

echo "🔧 Instalando dependências..."
sudo pacman -S --needed --noconfirm base-devel git

echo "📥 Clonando repositório do yay..."
git clone https://aur.archlinux.org/yay.git

cd yay

echo "⚙️ Compilando e instalando yay..."
makepkg -si --noconfirm

cd ..
rm -rf yay

echo "✅ yay instalado com sucesso!"
