#!/usr/bin/env bash
# ============================================================
#  Cria um usuário com privilégios de superusuário
#
#  Uso:
#    sudo ./create-superuser.sh -u <usuario> [-p <senha>] [-s <shell>] [-n]
#
#  Opções:
#    -u, --username   Nome do novo usuário (obrigatório)
#    -p, --password   Senha inicial (opcional; se omitida, será solicitada)
#    -s, --shell      Shell de login (padrão: /bin/bash)
#    -n, --nopasswd   Permite sudo sem senha (NOPASSWD)
#    -h, --help       Exibe esta ajuda
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

usage() {
    cat <<EOF
Uso: $0 -u <usuario> [-p <senha>] [-s <shell>] [-n]

Opções:
  -u, --username   Nome do novo usuário (obrigatório)
  -p, --password   Senha inicial (opcional; evite usar em histórico)
  -s, --shell      Shell de login (padrão: /bin/bash)
  -n, --nopasswd   Permite sudo sem senha (NOPASSWD)
  -h, --help       Exibe esta ajuda
EOF
    exit "${1:-1}"
}

# ------------------------------------------------------------
# Argumentos
# ------------------------------------------------------------
USERNAME=""
PASSWORD=""
SHELL="/bin/bash"
NOPASSWD=false
ORIGINAL_ARGS=("$@")

while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--username)
            [[ $# -ge 2 ]] || die "Falta o valor de $1."
            USERNAME="$2"
            shift 2
            ;;
        -p|--password)
            [[ $# -ge 2 ]] || die "Falta o valor de $1."
            PASSWORD="$2"
            shift 2
            ;;
        -s|--shell)
            [[ $# -ge 2 ]] || die "Falta o valor de $1."
            SHELL="$2"
            shift 2
            ;;
        -n|--nopasswd)
            NOPASSWD=true
            shift
            ;;
        -h|--help)
            usage 0
            ;;
        *)
            die "Opção desconhecida: $1"
            ;;
    esac
done

[[ -n "$USERNAME" ]] || { printf '%s❌ O nome de usuário é obrigatório.%s\n' "$C_RED" "$C_RESET" >&2; usage 1; }

# ------------------------------------------------------------
# Root (re-executa com sudo, se necessário)
# ------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        SCRIPT_PATH="$(readlink -f -- "$0" 2>/dev/null || printf '%s' "$0")"
        exec sudo -- bash "$SCRIPT_PATH" "${ORIGINAL_ARGS[@]}"
    fi
    die "Execute como root: sudo $0 -u <usuario>"
fi

# ------------------------------------------------------------
# Validações
# ------------------------------------------------------------
[[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] \
    || die "Nome de usuário inválido. Use letras minúsculas, números, _ e - (até 32 caracteres)."

if id "$USERNAME" >/dev/null 2>&1; then
    die "O usuário '$USERNAME' já existe."
fi

[[ -x "$SHELL" ]] || die "O shell '$SHELL' não existe ou não é executável."

if [[ -r /etc/shells ]] && ! grep -qxF "$SHELL" /etc/shells; then
    warn "O shell '$SHELL' não está listado em /etc/shells."
fi

if [[ -n "$PASSWORD" && "$PASSWORD" == *:* ]]; then
    die "A senha não pode conter ':'."
fi

ADMIN_GROUP=""
for group in sudo wheel admin; do
    if getent group "$group" >/dev/null 2>&1; then
        ADMIN_GROUP="$group"
        break
    fi
done
if [[ -z "$ADMIN_GROUP" ]]; then
    for group in sudo wheel admin; do
        if grep -q "^${group}:" /etc/group 2>/dev/null; then
            ADMIN_GROUP="$group"
            break
        fi
    done
fi
[[ -n "$ADMIN_GROUP" ]] || die "Nenhum grupo administrativo encontrado (wheel, sudo ou admin)."

# ------------------------------------------------------------
# Criação do usuário
# ------------------------------------------------------------
info "Criando usuário '$USERNAME'..."
useradd -m -s "$SHELL" "$USERNAME"

if [[ -z "$PASSWORD" ]]; then
    info "Definindo a senha de '$USERNAME'..."
    passwd "$USERNAME"
else
    warn "A senha informada por -p pode ficar registrada no histórico do shell."
    printf '%s:%s\n' "$USERNAME" "$PASSWORD" | chpasswd
    ok "Senha definida."
fi

info "Adicionando '$USERNAME' ao grupo '$ADMIN_GROUP'..."
usermod -aG "$ADMIN_GROUP" "$USERNAME"

# ------------------------------------------------------------
# Sudo sem senha (opcional)
# ------------------------------------------------------------
if [[ "$NOPASSWD" == true ]]; then
    info "Configurando sudo sem senha..."
    mkdir -p /etc/sudoers.d
    tmp_sudoers="$(mktemp)"
    printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$USERNAME" > "$tmp_sudoers"

    if command -v visudo >/dev/null 2>&1; then
        if ! visudo -cf "$tmp_sudoers" >/dev/null 2>&1; then
            rm -f "$tmp_sudoers"
            die "A regra de sudo gerada é inválida."
        fi
    fi

    install -m 0440 "$tmp_sudoers" "/etc/sudoers.d/90-$USERNAME"
    rm -f "$tmp_sudoers"
    ok "Arquivo /etc/sudoers.d/90-$USERNAME criado."
fi

# ------------------------------------------------------------
# Primeiro login
# ------------------------------------------------------------
if command -v chage >/dev/null 2>&1; then
    chage -d 0 "$USERNAME"
    info "O usuário deverá trocar a senha no primeiro login."
else
    warn "chage não encontrado; não foi possível forçar a troca de senha."
fi

# ------------------------------------------------------------
# Resumo
# ------------------------------------------------------------
HOME_DIR="$(getent passwd "$USERNAME" 2>/dev/null | cut -d: -f6 || true)"
[[ -n "$HOME_DIR" ]] || HOME_DIR="/home/$USERNAME"

printf '\n'
ok "Usuário '$USERNAME' criado com sucesso!"
printf '  %sHome:%s        %s\n' "$C_YELLOW" "$C_RESET" "$HOME_DIR"
printf '  %sShell:%s       %s\n' "$C_YELLOW" "$C_RESET" "$SHELL"
printf '  %sGrupo:%s       %s\n' "$C_YELLOW" "$C_RESET" "$ADMIN_GROUP"
if [[ "$NOPASSWD" == true ]]; then
    printf '  %sSudo:%s        NOPASSWD (sem senha)\n' "$C_YELLOW" "$C_RESET"
else
    printf '  %sSudo:%s        requer senha\n' "$C_YELLOW" "$C_RESET"
fi
printf '\n%sFaça logout e login novamente para aplicar os grupos.%s\n' "$C_YELLOW" "$C_RESET"
