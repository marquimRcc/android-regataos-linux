#!/bin/bash
# ==============================================================================
# Script de Instalação Automatizada do Android (Waydroid) no Regata OS
# Compatível com máquinas recém-formatadas ou instalações limpas do Regata OS
# ==============================================================================

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${BLUE}================================================================${NC}"
echo -e "${BOLD}${GREEN}     Instalador Automatizado do Android (Waydroid) no Regata OS ${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# 1. Solicitar permissões de administrador no início
echo -e "${YELLOW}[1/6] Verificando privilégios de administrador (sudo)...${NC}"
if ! sudo -v; then
    echo -e "${RED}Erro: Senha incorreta ou permissão recusada.${NC}"
    read -p "Pressione [Enter] para fechar..."
    exit 1
fi

# Manter sudo vivo durante a execução do script
while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &

# 2. Instalar dependências base do sistema
echo -e "\n${YELLOW}[2/6] Instalando dependências do sistema via zypper...${NC}"
sudo zypper --non-interactive install --no-recommends \
    lxc \
    python313-gobject \
    python313-pyclipper \
    python313-gbinder \
    curl \
    tar

# 3. Baixar e instalar o Waydroid (contornando falso conflito de versão do repositório)
echo -e "\n${YELLOW}[3/6] Instalando pacote Waydroid oficial...${NC}"
if ! command -v waydroid &>/dev/null; then
    echo "Baixando pacote Waydroid do repositório regataos..."
    zypper --non-interactive download waydroid || true
    
    WAYDROID_RPM=$(find "$HOME/.cache/zypp/packages" /var/cache/zypp/packages -name "waydroid*.rpm" 2>/dev/null | head -n 1)
    if [ -n "$WAYDROID_RPM" ]; then
        sudo rpm -Uvh --replacepkgs --nodeps "$WAYDROID_RPM"
    else
        echo -e "${RED}Aviso: Não foi possível localizar o rpm do Waydroid no cache. Tentando instalação forçada via zypper...${NC}"
        sudo zypper --non-interactive install --force-resolution waydroid || true
    fi
else
    echo -e "${GREEN}Pacote Waydroid já instalado!${NC}"
fi

# 4. Atualizar libgbinder1 (garante compatibilidade com Python 3.13)
echo -e "\n${YELLOW}[4/6] Verificando biblioteca libgbinder1...${NC}"
if ! nm -D /usr/lib64/libgbinder.so.1 2>/dev/null | grep -q "gbinder_servicemanager_new2"; then
    echo "Atualizando libgbinder1 para versão com suporte a runtime binder..."
    TMP_RPM="/tmp/libgbinder1_updated.rpm"
    curl -L -s -o "$TMP_RPM" "https://download.opensuse.org/repositories/home:/xanders:/libraries/openSUSE_Tumbleweed/x86_64/libgbinder1-1.1.53+git0.gfd67150-65.1.x86_64.rpm"
    if [ -f "$TMP_RPM" ]; then
        sudo rpm -Uvh --replacepkgs "$TMP_RPM"
        rm -f "$TMP_RPM"
    fi
else
    echo -e "${GREEN}Biblioteca libgbinder1 já está na versão compatível!${NC}"
fi

# 5. Habilitar serviço do contêiner e inicializar a imagem do Android
echo -e "\n${YELLOW}[5/6] Configurando contêiner e imagens do sistema...${NC}"
sudo systemctl enable --now waydroid-container

if [ ! -f /var/lib/waydroid/images/system.img ]; then
    echo -e "${BLUE}Baixando imagem oficial do Android GAPPS (Google Play Store)...${NC}"
    echo "Isso pode levar alguns minutos (download de ~1GB)..."
    sudo waydroid init -s GAPPS
else
    echo -e "${GREEN}Imagens do Android já estão instaladas!${NC}"
fi

# 6. Configurar traduções ARM (libndk) para permitir rodar jogos e aplicativos de celular
echo -e "\n${YELLOW}[6/6] Configurando suporte para jogos e apps ARM (libndk)...${NC}"
SCRIPT_DIR="$HOME/waydroid_script"

if [ ! -d "$SCRIPT_DIR" ]; then
    echo "Baixando script de extras e traduções..."
    mkdir -p "$SCRIPT_DIR"
    curl -L -s https://github.com/casualsnek/waydroid_script/archive/refs/heads/main.tar.gz | tar -xz --strip-components=1 -C "$SCRIPT_DIR"
fi

if [ ! -d "$SCRIPT_DIR/venv" ]; then
    echo "Criando ambiente virtual Python para os scripts..."
    python3 -m venv "$SCRIPT_DIR/venv"
    "$SCRIPT_DIR/venv/bin/pip" install --quiet -r "$SCRIPT_DIR/requirements.txt"
fi

# Verificar se a tradução ARM já está ativa no waydroid.cfg
if ! grep -q "libndk" /var/lib/waydroid/waydroid.cfg 2>/dev/null; then
    echo "Instalando tradutor ARM libndk..."
    cd "$SCRIPT_DIR"
    sudo "$SCRIPT_DIR/venv/bin/python3" main.py install libndk
else
    echo -e "${GREEN}Tradutor ARM libndk já configurado e ativo!${NC}"
fi

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BOLD}${GREEN}        INSTALAÇÃO E CONFIGURAÇÃO CONCLUÍDAS COM SUCESSO!        ${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""
echo -e "${BOLD}Como abrir o Android:${NC}"
echo -e "1. Na tela de bloqueio/login do Regata OS, mude a sessão de"
echo -e "   'Plasma (X11)' para ${BOLD}${YELLOW}'Plasma (Wayland)'${NC}."
echo -e "2. Após fazer login, clique no ícone ${GREEN}Waydroid${NC} no menu iniciar"
echo -e "   ou digite no terminal: ${BOLD}waydroid show-full-ui${NC}"
echo ""
echo -e "${BOLD}Google Play Store (se pedir certificação de dispositivo):${NC}"
echo -e "Execute no terminal: ${YELLOW}cd ~/waydroid_script && ./venv/bin/python3 main.py certified${NC}"
echo -e "e registre o código gerado em: ${BLUE}https://www.google.com/android/uncertified/${NC}"
echo ""
read -p "Pressione [Enter] para fechar..."
