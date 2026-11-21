<div align="center">

# 🐧 Script-Linux

**Scripts para automatizar a configuração do seu Linux — organizados por categoria.**

![Shell Script](https://img.shields.io/badge/Shell_Script-121011?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen?style=for-the-badge)

`Debian` · `Ubuntu` · `Arch` · `Fedora` · `Void` · `openSUSE` · `Alpine`

</div>

---

## Sobre

Uma coleção de scripts em Shell para deixar a configuração do Linux mais rápida e prática: instalação de aplicativos, ambiente de desenvolvimento, jogos, redes/VPNs, servidores e personalização do sistema.

Cada script detecta a distribuição automaticamente quando possível e instala tudo pelo gerenciador de pacotes nativo — sem Snap.

## Começando

```bash
# 1. Clone o repositório
git clone https://github.com/dedectr/Script-Linux.git
cd Script-Linux

# 2. Abra o menu interativo
./menu.sh
```

O menu mostra as categorias, descreve cada script e executa a opção escolhida. Os scripts que precisam de root são executados com `sudo` automaticamente.

> [!NOTE]
> Também é possível rodar um script diretamente:
> ```bash
> ./aplicativos/install-apps.sh
> ./rede/install-openvpn.sh
> ```
> Alguns scripts precisam ser executados com `sudo` (ou pedem a senha durante a execução).

## Menu interativo

```text
╭──────────────────────────────────────────────────────────────╮
  🐧  SCRIPT-LINUX
  Seu Linux
╰──────────────────────────────────────────────────────────────╯

  [1] 🖥️  Aplicativos            (2 scripts)
  [2] 💻 Desenvolvimento         (1 scripts)
  [3] 🎮 Jogos                   (2 scripts)
  [4] 🌐 Rede e VPN              (5 scripts)
  [5] 🖧  Servidor               (1 scripts)
  [6] ⚙️  Sistema                (4 scripts)

  [7] 📖 Abrir README
  [8] 🔄 Atualizar repositório (git pull)
  [0] 🚪 Sair
```

## Estrutura

```text
Script-Linux/
├── aplicativos/
│   ├── install-apps.sh
│   └── install-flatpak-apps.sh
├── desenvolvimento/
│   └── dev-setup.sh
├── jogos/
│   ├── install-games.sh
│   └── minecraft-server.sh
├── rede/
│   ├── auto-config-rede.sh
│   ├── install-hamachi-arch.sh
│   ├── install-hamachi-void.sh
│   ├── install-openvpn.sh
│   └── install-zerotier.sh
├── servidor/
│   └── create-superuser.sh
├── sistema/
│   ├── icons-terminal.sh
│   ├── install-bluetooth-pulse.sh
│   ├── install-hyprland-arch.sh
│   └── yay.sh
├── menu.sh
└── README.md
```

## Scripts

### 🖥️ Aplicativos

| Script | Descrição | Distros |
| --- | --- | --- |
| [`install-apps.sh`](aplicativos/install-apps.sh) | Instala OBS, Kdenlive, GIMP, Audacity, VLC, Wine, Lutris e Flatpak pelo gerenciador nativo. Também instala o Zoom via Flatpak. | Debian/Ubuntu, Arch, Fedora, Void, openSUSE |
| [`install-flatpak-apps.sh`](aplicativos/install-flatpak-apps.sh) | Menu com multiseleção para instalar apps de produtividade via Flatpak: comunicação, escritório, navegadores, multimídia, notas e e-mail. | Multi-distro |

### 💻 Desenvolvimento

| Script | Descrição | Distros |
| --- | --- | --- |
| [`dev-setup.sh`](desenvolvimento/dev-setup.sh) | Ambiente completo com Vim, Neovim e VS Code, além de Python, C/C++, Java, Rust, Go, JS, PHP, SQL, CMake e ferramentas de terminal. | Debian/Ubuntu, Arch, Fedora, Void, openSUSE |

### 🎮 Jogos

| Script | Descrição | Distros |
| --- | --- | --- |
| [`install-games.sh`](jogos/install-games.sh) | Instala Steam, Heroic Games Launcher, Lutris, Itch.io, RetroArch, Bottles, ProtonUp-Qt e MangoHUD via Flatpak, com relatório de falhas. | Multi-distro |
| [`minecraft-server.sh`](jogos/minecraft-server.sh) | Menu para instalar, iniciar, parar, reiniciar, abrir o console, ver o status e criar backups de um servidor Purpur. | Qualquer distro com Java 21 + `screen` |

### 🌐 Rede e VPN

| Script | Descrição | Distros |
| --- | --- | --- |
| [`auto-config-rede.sh`](rede/auto-config-rede.sh) | Ativa as interfaces físicas e solicita IP via DHCP, com suporte a `udhcpc`, `dhclient` e `dhcpcd`. | Alpine, Void e sistemas com BusyBox |
| [`install-hamachi-arch.sh`](rede/install-hamachi-arch.sh) | Instala e configura o Hamachi no Arch Linux via AUR, com suporte a `yay` ou `paru`. | Arch |
| [`install-hamachi-void.sh`](rede/install-hamachi-void.sh) | Instala o Hamachi no Void Linux a partir do pacote oficial, com serviço runit. | Void |
| [`install-openvpn.sh`](rede/install-openvpn.sh) | Configura servidor OpenVPN com easy-rsa, CRL, NAT automático e menu para criar, revogar e listar clientes. | Multi-distro |
| [`install-zerotier.sh`](rede/install-zerotier.sh) | Compila e instala o ZeroTier com suporte a systemd, OpenRC e runit. | Multi-distro |

### 🖧 Servidor

| Script | Descrição | Distros |
| --- | --- | --- |
| [`create-superuser.sh`](servidor/create-superuser.sh) | Cria um usuário com privilégios de superusuário, shell e senha personalizados, com opção de `sudo` sem senha e validação da regra. | Fedora Server e derivados com grupo administrativo |

### ⚙️ Sistema

| Script | Descrição | Distros |
| --- | --- | --- |
| [`icons-terminal.sh`](sistema/icons-terminal.sh) | Instala emojis, ícones, fontes Powerline e FiraCode Nerd Font no seu usuário. | Debian/Ubuntu, Arch, Fedora, Void, openSUSE, Alpine |
| [`install-bluetooth-pulse.sh`](sistema/install-bluetooth-pulse.sh) | Instala e ativa Bluetooth + PulseAudio no Void Linux, incluindo D-Bus e `rfkill`. | Void |
| [`install-hyprland-arch.sh`](sistema/install-hyprland-arch.sh) | Setup completo do Hyprland: Waybar, Rofi, Alacritty, SDDM, fontes e configurações prontas com tema escuro. | Arch |
| [`yay.sh`](sistema/yay.sh) | Instala o `yay` (AUR helper) no Arch Linux de forma segura, usando diretório temporário. | Arch |

## Destaques

- 🧭 **Menu único** para navegar por todas as categorias.
- 🛡️ **Verificações** de root, sudo, dependências e distribuição.
- 🎨 **Saída colorida** e mensagens claras de sucesso, aviso e erro.
- 🧹 **Limpeza automática** de diretórios temporários.
- 💾 **Backups** antes de sobrescrever configurações do Hyprland/Waybar.
- 🔐 **OpenVPN** com CRL, NAT persistente e perfis de cliente com permissão `600`.
- 🧩 **Instalações resilientes**: se um pacote falhar, o script continua e informa o que faltou.

## Requisitos

- Linux com `bash` (a maioria dos scripts) ou `sh` (rede/OpenVPN).
- `sudo` para instalação de pacotes.
- Conexão com a internet para baixar pacotes, fontes e perfis.

## Avisos

> [!WARNING]
> Os scripts executam comandos com `sudo` e alteram configurações do sistema. Revise o conteúdo antes de executar e use por sua conta e risco.

> [!TIP]
> Prefira executar um script por vez e leia as mensagens no terminal. Assim fica fácil identificar qualquer erro específico da sua distro.

## Contribuindo

1. Faça um fork do projeto
2. Crie uma branch: `git checkout -b minha-melhoria`
3. Faça o commit: `git commit -m "feat: minha melhoria"`
4. Envie: `git push origin minha-melhoria`
5. Abra um Pull Request

Sugestões, correções e novos scripts são bem-vindos! 🚀
