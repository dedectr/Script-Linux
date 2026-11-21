#!/usr/bin/env bash
#
# create_superuser.sh - Cria um usuário com privilégios de superusuário no Fedora Server.
#
# Uso:
#   sudo ./create_superuser.sh -u <usuario> [-p <senha>] [-s <shell>] [-n]
#
# Opções:
#   -u, --username   Nome do novo usuário (obrigatório)
#   -p, --password   Senha inicial (opcional; se omitida, será solicitada)
#   -s, --shell      Shell de login (padrão: /bin/bash)
#   -n, --nopasswd   Permite sudo sem senha (NOPASSWD) para o usuário
#   -h, --help       Exibe esta ajuda
#
# O script deve ser executado como root ou com privilégios de sudo.

set -euo pipefail

# Cores para saída (opcional)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------
# Função de uso
# ------------------------------------------------------------------
usage() {
    echo "Uso: $0 -u <usuario> [-p <senha>] [-s <shell>] [-n]"
    echo "  -u, --username   Nome do novo usuário (obrigatório)"
    echo "  -p, --password   Senha inicial (opcional)"
    echo "  -s, --shell      Shell de login (padrão: /bin/bash)"
    echo "  -n, --nopasswd   Permite sudo sem senha (NOPASSWD)"
    echo "  -h, --help       Exibe esta ajuda"
    exit 1
}

# ------------------------------------------------------------------
# Verifica se está rodando como root ou se pode usar sudo
# ------------------------------------------------------------------
if [[ "${EUID}" -ne 0 ]]; then
    if command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
        # Reexecuta o script com sudo, preservando os argumentos
        exec sudo -- "$0" "$@"
    else
        echo -e "${RED}Erro: este script precisa ser executado como root ou por um usuário com sudo sem senha.${NC}" >&2
        exit 1
    fi
fi

# ------------------------------------------------------------------
# Valores padrão
# ------------------------------------------------------------------
USERNAME=""
PASSWORD=""
SHELL="/bin/bash"
NOPASSWD=false

# ------------------------------------------------------------------
# Parse dos argumentos
# ------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--username)
            USERNAME="$2"
            shift 2
            ;;
        -p|--password)
            PASSWORD="$2"
            shift 2
            ;;
        -s|--shell)
            SHELL="$2"
            shift 2
            ;;
        -n|--nopasswd)
            NOPASSWD=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Opção desconhecida: $1${NC}" >&2
            usage
            ;;
    esac
done

# ------------------------------------------------------------------
# Validações
# ------------------------------------------------------------------
if [[ -z "${USERNAME}" ]]; then
    echo -e "${RED}Erro: o nome de usuário é obrigatório.${NC}" >&2
    usage
fi

# Verifica se o usuário já existe
if id "${USERNAME}" &>/dev/null; then
    echo -e "${RED}Erro: o usuário '${USERNAME}' já existe.${NC}" >&2
    exit 1
fi

# ------------------------------------------------------------------
# Criação do usuário
# ------------------------------------------------------------------
echo -e "${YELLOW}→ Criando usuário '${USERNAME}'...${NC}"

# Cria o usuário com home directory e shell definidos
useradd -m -s "${SHELL}" "${USERNAME}"

# ------------------------------------------------------------------
# Definição da senha
# ------------------------------------------------------------------
if [[ -z "${PASSWORD}" ]]; then
    # Solicita a senha interativamente
    echo -e "${YELLOW}→ Definindo senha para '${USERNAME}'...${NC}"
    passwd "${USERNAME}"
else
    # Define a senha de forma não interativa
    echo "${USERNAME}:${PASSWORD}" | chpasswd
    echo -e "${GREEN}Senha definida para '${USERNAME}'.${NC}"
fi

# ------------------------------------------------------------------
# Adiciona ao grupo wheel (superusuário)
# ------------------------------------------------------------------
echo -e "${YELLOW}→ Adicionando '${USERNAME}' ao grupo 'wheel'...${NC}"
usermod -aG wheel "${USERNAME}"

# ------------------------------------------------------------------
# Configuração opcional de sudo sem senha (NOPASSWD)
# ------------------------------------------------------------------
if [[ "${NOPASSWD}" == true ]]; then
    SUDOERS_FILE="/etc/sudoers.d/${USERNAME}"
    echo -e "${YELLOW}→ Configurando sudo sem senha para '${USERNAME}'...${NC}"
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "${SUDOERS_FILE}"
    chmod 0440 "${SUDOERS_FILE}"
    echo -e "${GREEN}Arquivo ${SUDOERS_FILE} criado com permissões 0440.${NC}"
fi

# ------------------------------------------------------------------
# Força a troca de senha no primeiro login (boa prática)
# ------------------------------------------------------------------
echo -e "${YELLOW}→ Forçando alteração de senha no primeiro login...${NC}"
chage -d 0 "${USERNAME}"

# ------------------------------------------------------------------
# Exibe resumo
# ------------------------------------------------------------------
echo -e "\n${GREEN}✔ Usuário '${USERNAME}' criado com sucesso!${NC}"
echo -e "  • Home:        /home/${USERNAME}"
echo -e "  • Shell:       ${SHELL}"
echo -e "  • Grupo sudo:  wheel"
if [[ "${NOPASSWD}" == true ]]; then
    echo -e "  • Sudo:        NOPASSWD (sem senha)"
else
    echo -e "  • Sudo:        requer senha"
fi
echo -e "\n${YELLOW}O usuário precisará alterar a senha no primeiro login.${NC}"
echo -e "${YELLOW}Faça logout e login novamente para que as alterações de grupo tenham efeito.${NC}"
