#!/usr/bin/env bash
# ============================================================
#  Servidor de Minecraft (Purpur) com menu
#  Variáveis opcionais:
#    MINECRAFT_VERSION, MC_RAM_MIN, MC_RAM_MAX,
#    MC_DIR, MC_JAR, MC_SESSION, MC_BACKUP_DIR
# ============================================================

set -euo pipefail

VERSION="${MINECRAFT_VERSION:-1.21.10}"
RAM_MIN="${MC_RAM_MIN:-1G}"
RAM_MAX="${MC_RAM_MAX:-2G}"
JAR="${MC_JAR:-purpur.jar}"
PASTA="${MC_DIR:-mc-server}"
SESSION="${MC_SESSION:-minecraft}"
BACKUP_DIR="${MC_BACKUP_DIR:-backups}"

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
    C_CYAN=$'\033[36m'
else
    C_RESET="" C_BOLD="" C_DIM="" C_RED="" C_GREEN=""
    C_YELLOW="" C_BLUE="" C_CYAN=""
fi

info() { printf '%sℹ️  %s%s\n' "$C_BLUE" "$*" "$C_RESET"; }
ok()   { printf '%s✅ %s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
warn() { printf '%s⚠️  %s%s\n' "$C_YELLOW" "$*" "$C_RESET"; }
die()  { printf '%s❌ %s%s\n' "$C_RED" "$*" "$C_RESET" >&2; exit 1; }

clear_screen() { if [[ -t 1 ]]; then clear; fi; }
pause() {
    printf '\n%sPressione ENTER para continuar...%s' "$C_DIM" "$C_RESET"
    read -r _ || true
}

# ------------------------------------------------------------
# Dependências
# ------------------------------------------------------------
need_java() {
    command -v java >/dev/null 2>&1 \
        || die "Java não encontrado. Instale o Java 21+ (ex.: openjdk-21-jre)."
}

need_screen() {
    command -v screen >/dev/null 2>&1 \
        || die "screen não encontrado. Instale com o gerenciador de pacotes da sua distro."
}

need_wget() {
    command -v wget >/dev/null 2>&1 \
        || die "wget não encontrado. Instale com o gerenciador de pacotes da sua distro."
}

check_java_version() {
    local version major
    version="$(java -version 2>&1 | awk -F'"' '/version/ {print $2; exit}')"
    [[ -n "$version" ]] || return 0

    major="${version%%.*}"
    if [[ "$major" == "1" ]]; then
        major="$(printf '%s' "$version" | cut -d. -f2)"
    fi

    if [[ "$major" =~ ^[0-9]+$ ]] && (( major < 21 )); then
        warn "Java $version detectado. O Minecraft $VERSION recomenda Java 21 ou superior."
    fi
}

session_running() {
    screen -ls 2>/dev/null | grep -qE "[0-9]+\.${SESSION}[[:space:]]"
}

# ------------------------------------------------------------
# Ações
# ------------------------------------------------------------
instalar() {
    need_wget
    mkdir -p "$PASTA"

    (
        cd "$PASTA"

        if [[ ! -s "$JAR" ]]; then
            info "Baixando Purpur $VERSION..."
            if ! wget -O "$JAR.tmp" \
                "https://api.purpurmc.org/v2/purpur/$VERSION/latest/download"; then
                rm -f "$JAR.tmp"
                die "Falha ao baixar o servidor. Verifique sua conexão."
            fi
            mv "$JAR.tmp" "$JAR"
        else
            ok "O arquivo $JAR já existe."
        fi

        printf 'eula=true\n' > eula.txt

        if [[ ! -f server.properties ]]; then
            cat > server.properties <<'EOF'
view-distance=6
simulation-distance=4
max-players=10
motd=Servidor com Menu :)
online-mode=true
EOF
        fi
    )

    ok "Servidor instalado em $PASTA/"
    pause
}

iniciar() {
    need_java
    need_screen

    [[ -f "$PASTA/$JAR" ]] || die "Servidor não instalado. Use a opção 1 primeiro."

    if session_running; then
        warn "O servidor já está rodando."
        return 0
    fi

    check_java_version
    info "Iniciando servidor..."

    (
        cd "$PASTA"
        screen -dmS "$SESSION" java \
            -Xms"$RAM_MIN" -Xmx"$RAM_MAX" \
            -XX:+UseG1GC \
            -XX:+ParallelRefProcEnabled \
            -XX:MaxGCPauseMillis=200 \
            -XX:+UnlockExperimentalVMOptions \
            -XX:+DisableExplicitGC \
            -XX:+AlwaysPreTouch \
            -XX:G1HeapRegionSize=8M \
            -XX:G1NewSizePercent=30 \
            -XX:G1MaxNewSizePercent=40 \
            -XX:G1HeapWastePercent=5 \
            -XX:G1MixedGCCountTarget=4 \
            -XX:InitiatingHeapOccupancyPercent=15 \
            -XX:G1MixedGCLiveThresholdPercent=90 \
            -XX:G1RSetUpdatingPauseTimePercent=5 \
            -XX:SurvivorRatio=32 \
            -XX:+PerfDisableSharedMem \
            -XX:MaxTenuringThreshold=1 \
            -jar "$JAR" nogui
    )

    sleep 2
    if session_running; then
        ok "Servidor iniciado."
        info "Use a opção 5 para abrir o console."
    else
        die "O servidor não iniciou. Abra o console ou verifique os logs em $PASTA/logs/."
    fi
}

parar() {
    need_screen

    if ! session_running; then
        warn "O servidor não está rodando."
        return 0
    fi

    info "Enviando comando stop..."
    screen -S "$SESSION" -X stuff $'stop\r'

    local waited=0
    while (( waited < 60 )); do
        if ! session_running; then
            ok "Servidor parado."
            return 0
        fi
        sleep 1
        waited=$((waited + 1))
    done

    warn "O servidor ainda está rodando. Use o console para verificar."
}

reiniciar() {
    parar
    if session_running; then
        warn "Reinício cancelado: o servidor ainda está rodando."
        return 0
    fi
    sleep 1
    iniciar
}

console() {
    need_screen

    if ! session_running; then
        warn "O servidor não está rodando."
        return 0
    fi

    info "Para sair do console sem parar o servidor: Ctrl+A e depois D."
    sleep 1
    screen -r "$SESSION"
}

status() {
    if session_running; then
        printf '%s🟢 Servidor ONLINE%s\n' "$C_GREEN" "$C_RESET"
    else
        printf '%s🔴 Servidor OFFLINE%s\n' "$C_RED" "$C_RESET"
    fi
    pause
}

backup() {
    [[ -d "$PASTA" ]] || die "A pasta do servidor ainda não existe. Instale primeiro."

    if session_running; then
        warn "O servidor está online. O backup pode ficar inconsistente."
        local resp
        read -rp "Continuar mesmo assim? [s/N]: " resp || return 0
        [[ "${resp,,}" == "s" ]] || return 0
    fi

    mkdir -p "$BACKUP_DIR"

    local -a items=()
    local item
    for item in world world_nether world_the_end server.properties plugins; do
        [[ -e "$PASTA/$item" ]] && items+=("$item")
    done

    ((${#items[@]})) || die "Nada para incluir no backup."

    local file
    file="$BACKUP_DIR/mc-$(date +%Y%m%d-%H%M%S).tar.gz"
    info "Criando backup..."
    tar -czf "$file" -C "$PASTA" "${items[@]}"
    ok "Backup criado: $file ($(du -h "$file" | cut -f1))"
    pause
}

# ------------------------------------------------------------
# Menu
# ------------------------------------------------------------
while true; do
    clear_screen
    printf '%s╭──────────────────────────────────────────────────────────────╮%s\n' "$C_BLUE" "$C_RESET"
    printf '  %s⛏️  MINECRAFT SERVER%s  %s(Purpur %s)%s\n' "$C_BOLD$C_CYAN" "$C_RESET" "$C_DIM" "$VERSION" "$C_RESET"
    if session_running; then
        printf '  %s🟢 online%s  ·  %sRAM: %s–%s%s\n' "$C_GREEN" "$C_RESET" "$C_DIM" "$RAM_MIN" "$RAM_MAX" "$C_RESET"
    else
        printf '  %s🔴 offline%s ·  %sRAM: %s–%s%s\n' "$C_RED" "$C_RESET" "$C_DIM" "$RAM_MIN" "$RAM_MAX" "$C_RESET"
    fi
    printf '%s╰──────────────────────────────────────────────────────────────╯%s\n\n' "$C_BLUE" "$C_RESET"

    printf '  %s[1]%s Instalar servidor\n' "$C_YELLOW" "$C_RESET"
    printf '  %s[2]%s Iniciar servidor\n' "$C_YELLOW" "$C_RESET"
    printf '  %s[3]%s Parar servidor\n' "$C_YELLOW" "$C_RESET"
    printf '  %s[4]%s Reiniciar servidor\n' "$C_YELLOW" "$C_RESET"
    printf '  %s[5]%s Abrir console\n' "$C_YELLOW" "$C_RESET"
    printf '  %s[6]%s Ver status\n' "$C_YELLOW" "$C_RESET"
    printf '  %s[7]%s Criar backup\n' "$C_YELLOW" "$C_RESET"
    printf '  %s[0]%s Sair\n\n' "$C_YELLOW" "$C_RESET"

    read -rp "Escolha: " opcao || exit 0

    case "$opcao" in
        1) instalar ;;
        2) iniciar ;;
        3) parar ;;
        4) reiniciar ;;
        5) console ;;
        6) status ;;
        7) backup ;;
        0) exit 0 ;;
        *) warn "Opção inválida: $opcao"; sleep 1 ;;
    esac
done
