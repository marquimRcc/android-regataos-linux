#!/bin/bash
# ==============================================================================
# Script de Instalação Automatizada do Android (Waydroid) no Regata OS
# Repositório: https://github.com/marquimRcc/android-regataos-linux
# Autor: Marcos Vinicios <marquim.rcc@gmail.com>
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
echo -e "${YELLOW}[1/7] Verificando privilégios de administrador (sudo)...${NC}"
if ! sudo -v; then
    echo -e "${RED}Erro: Senha incorreta ou permissão recusada.${NC}"
    read -p "Pressione [Enter] para fechar..."
    exit 1
fi

# Manter sudo vivo durante a execução do script
while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &

# 2. Instalar dependências base do sistema
echo -e "\n${YELLOW}[2/7] Instalando dependências do sistema via zypper...${NC}"
sudo zypper --non-interactive install --no-recommends \
    lxc \
    python313-gobject \
    python313-pyclipper \
    python313-gbinder \
    dnsmasq \
    curl \
    tar \
    xclip

# 3. Baixar e instalar o Waydroid (contornando falso conflito de versão do repositório)
echo -e "\n${YELLOW}[3/7] Instalando pacote Waydroid oficial...${NC}"
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
echo -e "\n${YELLOW}[4/7] Verificando biblioteca libgbinder1...${NC}"
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
echo -e "\n${YELLOW}[5/7] Configurando contêiner e imagens do sistema...${NC}"
sudo systemctl enable --now waydroid-container

if [ ! -f /var/lib/waydroid/images/system.img ]; then
    echo -e "${BLUE}Baixando imagem oficial do Android GAPPS (Google Play Store)...${NC}"
    echo "Isso pode levar alguns minutos (download de ~1GB)..."
    sudo waydroid init -s GAPPS
else
    echo -e "${GREEN}Imagens do Android já estão instaladas!${NC}"
fi

# 6. Configurar traduções ARM (libndk) para permitir rodar jogos e aplicativos de celular
echo -e "\n${YELLOW}[6/7] Configurando suporte para jogos e apps ARM (libndk)...${NC}"
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

# 7. Otimizações de Desempenho e Usabilidade Pós-Instalação
echo -e "\n${YELLOW}[7/7] Aplicando otimizações de desempenho e atalhos...${NC}"

# 7.1 Otimização de latência do cursor no Wayland
sudo waydroid prop set persist.waydroid.cursor_on_subsurface true 2>/dev/null || true

# 7.2 Instalação com 2 cliques ou botão direito para arquivos .APK
mkdir -p "$HOME/.local/share/kio/servicemenus" "$HOME/.local/share/applications"

cat << 'EOF' > "$HOME/.local/share/kio/servicemenus/waydroid-install.desktop"
[Desktop Entry]
Type=Service
ServiceTypes=KonqPopupMenu/Plugin
MimeType=application/vnd.android.package-archive;application/x-authorware-bin;
Actions=InstallWaydroid;

[Desktop Action InstallWaydroid]
Name=Instalar no Android (Waydroid)
Icon=waydroid
Exec=waydroid app install %f
EOF

cat << 'EOF' > "$HOME/.local/share/applications/waydroid-apk-installer.desktop"
[Desktop Entry]
Type=Application
Name=Instalador de APK (Waydroid)
Exec=waydroid app install %f
MimeType=application/vnd.android.package-archive;
Icon=waydroid
NoDisplay=false
Terminal=false
Categories=System;
EOF

# 7.3 Script utilitário para certificação da Play Store
mkdir -p "$HOME/.local/bin"
cat << 'EOF' > "$HOME/.local/bin/waydroid-cert"
#!/bin/bash
echo "Buscando ID de certificação do Google Play..."
ANDROID_ID=""

if [ -f "$HOME/waydroid_script/main.py" ]; then
    ANDROID_ID=$(sudo "$HOME/waydroid_script/venv/bin/python3" "$HOME/waydroid_script/main.py" certified 2>/dev/null | grep -oE '[0-9]{15,20}' | head -n 1)
fi

if [ -z "$ANDROID_ID" ]; then
    ANDROID_ID=$(sudo waydroid shell 'sqlite3 /data/data/com.google.android.gsf/databases/gservices.db "select value from main where name = \"android_id\";"' 2>/dev/null | tr -d '\r\n')
fi

if [ -n "$ANDROID_ID" ]; then
    echo "================================================="
    echo "ID do seu Android: $ANDROID_ID"
    echo "================================================="
    if command -v wl-copy &>/dev/null; then
        echo -n "$ANDROID_ID" | wl-copy 2>/dev/null
        echo "[OK] ID copiado para a área de transferência!"
    elif command -v xclip &>/dev/null; then
        echo -n "$ANDROID_ID" | xclip -selection clipboard 2>/dev/null
        echo "[OK] ID copiado para a área de transferência!"
    fi
    echo "Abrindo o navegador para registro..."
    xdg-open "https://www.google.com/android/uncertified/" 2>/dev/null &
else
    echo "Banco de dados da Play Store ainda não gerado. Abra o Waydroid pela primeira vez antes de registrar."
fi
read -p "Pressione [Enter] para fechar..."
EOF
chmod +x "$HOME/.local/bin/waydroid-cert"

# 7.4 Atalhos úteis na Área de Trabalho
DESKTOP_DIR="$HOME/Área de trabalho"
[ ! -d "$DESKTOP_DIR" ] && DESKTOP_DIR="$HOME/Desktop"

if [ -d "$DESKTOP_DIR" ]; then
    cat << 'EOF' > "$DESKTOP_DIR/Certificar-PlayStore.desktop"
[Desktop Entry]
Encoding=UTF-8
Version=1.0
Type=Application
Terminal=true
Exec=/home/pcmini/.local/bin/waydroid-cert
Name=Certificar Google Play
Comment=Obtém o ID e abre a página de liberação do Google Play Store
Icon=google-play
Categories=System;
EOF

    cat << 'EOF' > "$DESKTOP_DIR/Parar-Android.desktop"
[Desktop Entry]
Encoding=UTF-8
Version=1.0
Type=Application
Terminal=false
Exec=waydroid session stop
Name=Parar Android (Liberar RAM)
Comment=Encerra a sessão do Android e libera a memória RAM do sistema
Icon=system-shutdown
Categories=System;
EOF

    cat << 'EOF' > "$DESKTOP_DIR/PASSO-A-PASSO-COMO-USAR.txt"
====================================================================
           GUIA RÁPIDO: COMO USAR O ANDROID NO REGATA OS
====================================================================

Parabéns! O Android (Waydroid) já está instalado e otimizado.

--------------------------------------------------------------------
PASSO 1: ENTRAR NA SESSÃO WAYLAND (OBRIGATÓRIO)
--------------------------------------------------------------------
O Waydroid precisa da tecnologia Wayland para funcionar com aceleração
gráfica da sua placa de vídeo.

1. Vá no Menu Iniciar do Regata OS.
2. Clique em "Encerrar Sessão" (ou "Sair").
3. Na tela de login (onde digita sua senha):
   -> Olhe no CANTO INFERIOR ESQUERDO da tela.
   -> Clique no seletor de sessão e mude de "Plasma (X11)" para:
      "Plasma (Wayland)"
4. Digite sua senha e entre no sistema.

--------------------------------------------------------------------
PASSO 2: ABRIR O ANDROID
--------------------------------------------------------------------
1. Abra o Menu Iniciar e clique no ícone "Waydroid"
   (ou abra o terminal e digite: waydroid show-full-ui)
2. A tela do Android com a Google Play Store vai carregar!

--------------------------------------------------------------------
PASSO 3: LIBERAR A GOOGLE PLAY STORE (APENAS NA 1ª VEZ)
--------------------------------------------------------------------
Ao abrir a Play Store pela primeira vez, se aparecer o aviso:
"Dispositivo não certificado pelo Play Protect":

1. Vá até a sua Área de Trabalho.
2. Dê 2 cliques no atalho: "Certificar Google Play".
3. Ele vai capturar seu ID, COPIAR AUTOMATICAMENTE para a sua memória
   (Ctrl+C) e abrir o navegador oficial do Google.
4. Na página, basta colar (Ctrl+V) e clicar em "Registrar".
5. Em cerca de 5 a 10 minutos, a Play Store estará 100% liberada!

--------------------------------------------------------------------
DICAS ÚTEIS NO DIA A DIA:
--------------------------------------------------------------------
• INSTALAR JOGOS/APPS VIA ARQUIVO .APK:
  Basta clicar com o botão direito em qualquer arquivo .apk baixado
  e escolher "Instalar no Android (Waydroid)".

• FECHAR O ANDROID E LIBERAR MEMÓRIA RAM:
  Quando terminar de usar ou jogar, dê 2 cliques no atalho
  "Parar Android (Liberar RAM)" na Área de Trabalho.

• SUPORTE A CONTROLES (GAMEPAD):
  Controles de Xbox, PlayStation e USB/Bluetooth funcionam nativamente.
====================================================================
EOF

    chmod +x "$DESKTOP_DIR/Certificar-PlayStore.desktop" "$DESKTOP_DIR/Parar-Android.desktop" 2>/dev/null || true
fi

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BOLD}${GREEN}        INSTALAÇÃO E OTIMIZAÇÕES CONCLUÍDAS COM SUCESSO!         ${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""
echo -e "${BOLD}Otimizações ativas:${NC}"
echo -e "✔️ Redução de latência do mouse ativa"
echo -e "✔️ Clique direito em arquivos .APK para instalar direto"
echo -e "✔️ Atalho na Área de Trabalho para 'Parar Android' e liberar RAM"
echo -e "✔️ Atalho para 'Certificar Google Play' com cópia automática do ID"
echo ""
echo -e "${BOLD}Como abrir o Android:${NC}"
echo -e "1. Na tela de bloqueio/login do Regata OS, selecione a sessão ${BOLD}${YELLOW}'Plasma (Wayland)'${NC}."
echo -e "2. Abra o menu iniciar e clique em ${GREEN}Waydroid${NC} (ou digite ${BOLD}waydroid show-full-ui${NC})."
echo ""
read -p "Pressione [Enter] para fechar..."
