#!/bin/bash

# ==============================
# CONFIG
# ==============================
VERSION="1.21.10"
RAM_MIN="1G"
RAM_MAX="2G"
JAR="purpur.jar"
PASTA="mc-server"
SESSION="minecraft"

# ==============================
# FUNÇÕES
# ==============================

instalar() {
    echo "== Instalando servidor =="
    mkdir -p $PASTA
    cd $PASTA || exit

    if [ ! -f "$JAR" ]; then
        echo "== Baixando Purpur =="
        wget -O $JAR https://api.purpurmc.org/v2/purpur/$VERSION/latest/download
    fi

    echo "eula=true" > eula.txt

    if [ ! -f "server.properties" ]; then
        cat > server.properties <<EOL
view-distance=6
simulation-distance=4
max-players=10
motd=Servidor com Menu :)
EOL
    fi

    cd ..
}

iniciar() {
    cd $PASTA || exit

    if screen -list | grep -q "$SESSION"; then
        echo "Servidor já está rodando!"
        cd ..
        return
    fi

    echo "== Iniciando servidor =="

    screen -dmS $SESSION java -Xms$RAM_MIN -Xmx$RAM_MAX \
    -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 \
    -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC \
    -XX:+AlwaysPreTouch -XX:G1HeapRegionSize=8M \
    -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 \
    -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 \
    -XX:InitiatingHeapOccupancyPercent=15 \
    -XX:G1MixedGCLiveThresholdPercent=90 \
    -XX:G1RSetUpdatingPauseTimePercent=5 \
    -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem \
    -XX:MaxTenuringThreshold=1 \
    -jar $JAR nogui

    cd ..
}

parar() {
    if screen -list | grep -q "$SESSION"; then
        echo "== Parando servidor =="
        screen -S $SESSION -X stuff "stop$(printf '\r')"
    else
        echo "Servidor não está rodando."
    fi
}

reiniciar() {
    parar
    sleep 5
    iniciar
}

console() {
    if screen -list | grep -q "$SESSION"; then
        screen -r $SESSION
    else
        echo "Servidor não está rodando."
    fi
}

status() {
    if screen -list | grep -q "$SESSION"; then
        echo "🟢 Servidor ONLINE"
    else
        echo "🔴 Servidor OFFLINE"
    fi
}

# ==============================
# MENU
# ==============================

while true; do
    clear
    echo "=============================="
    echo "     MINE SERVER MENU"
    echo "=============================="
    echo "1. Instalar servidor"
    echo "2. Iniciar servidor"
    echo "3. Parar servidor"
    echo "4. Reiniciar servidor"
    echo "5. Console"
    echo "6. Status"
    echo "0. Sair"
    echo "=============================="
    read -p "Escolha: " opcao

    case $opcao in
        1) instalar ;;
        2) iniciar ;;
        3) parar ;;
        4) reiniciar ;;
        5) console ;;
        6) status ;;
        0) exit ;;
        *) echo "Opção inválida"; sleep 2 ;;
    esac
done
