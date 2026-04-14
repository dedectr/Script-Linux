#!/bin/bash

set -e

echo "🔍 Verificando se o yay está instalado..."
if ! command -v yay &> /dev/null
then
echo "❌ yay não encontrado! Instale o yay primeiro."
exit 1
fi

echo "📦 Instalando Hamachi (logmein-hamachi)..."
yay -S --noconfirm logmein-hamachi

echo "🚀 Iniciando serviço do Hamachi..."
sudo systemctl enable --now logmein-hamachi

echo "🔗 Logando no Hamachi..."
hamachi login

echo "✅ Hamachi instalado e iniciado!"
echo "👉 Use 'hamachi attach <email>' pra conectar sua conta"
echo "👉 Use 'hamachi join <rede> <senha>' pra entrar em uma rede"
