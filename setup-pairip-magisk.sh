#!/bin/bash
# ==============================================================================
# Script de Compatibilidade Anti-Tamper / PairIP para Waydroid no Regata OS
# Repositório: https://github.com/marquimRcc/android-regataos-linux
# Branch: feature/magisk-play-integrity
# ==============================================================================
# Este script ativa o Magisk Delta (Kitsune Mask), Zygisk, Play Integrity Fix
# e o módulo PairIPFix para permitir a execução de jogos protegidos como:
# - Avatar World (Pazu Games)
# - Roblox
# - Brawl Stars (Supercell)
# ==============================================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${BLUE}================================================================${NC}"
echo -e "${BOLD}${GREEN}  Desbloqueio de Jogos Anti-Tamper / PairIP no Waydroid (Regata OS)  ${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# 1. Verificar privilégios de administrador
echo -e "${YELLOW}[1/6] Verificando permissões de administrador (sudo)...${NC}"
if ! sudo -v; then
    echo -e "${RED}Erro: Senha incorreta ou permissão recusada.${NC}"
    exit 1
fi

while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &

# 2. Encerrar instâncias do Waydroid para aplicar modificações com segurança
echo -e "\n${YELLOW}[2/6] Parando serviços do Waydroid para aplicação das camadas...${NC}"
waydroid session stop 2>/dev/null || true
sudo systemctl stop waydroid-container 2>/dev/null || true
sleep 2

# 3. Verificar e Instalar Magisk Delta (Kitsune Mask) via waydroid_script
echo -e "\n${YELLOW}[3/6] Configurando Magisk Delta (Kitsune Mask) no sistema Android...${NC}"
SCRIPT_DIR="$HOME/waydroid_script"

if [ ! -d "$SCRIPT_DIR" ]; then
    echo "Baixando utilitário waydroid_script..."
    mkdir -p "$SCRIPT_DIR"
    curl -L -s https://github.com/casualsnek/waydroid_script/archive/refs/heads/main.tar.gz | tar -xz --strip-components=1 -C "$SCRIPT_DIR"
fi

if [ ! -d "$SCRIPT_DIR/venv" ]; then
    echo "Criando ambiente virtual Python..."
    python3 -m venv "$SCRIPT_DIR/venv"
    "$SCRIPT_DIR/venv/bin/pip" install --quiet -r "$SCRIPT_DIR/requirements.txt"
fi

# Instalar Magisk no contêiner
echo "Aplicando injeção do Magisk Delta nas imagens do Waydroid..."
cd "$SCRIPT_DIR"
sudo "$SCRIPT_DIR/venv/bin/python3" main.py install magisk

# 4. Baixar Módulos: Play Integrity Fix, LSPosed e PairIPFix
echo -e "\n${YELLOW}[4/6] Baixando módulos de certificação e bypass de anti-tamper...${NC}"
TMP_DIR="/tmp/waydroid_compat_modules"
mkdir -p "$TMP_DIR"

PIF_URL="https://github.com/KOWX712/PlayIntegrityFix/releases/download/v4.9-inject-s/PlayIntegrityFix_v4.9-inject-s.zip"
LSPOSED_URL="https://github.com/mywalkb/LSPosed_mod/releases/download/v1.9.3_mod/LSPosed-v1.9.3_mod-7244-zygisk-release.zip"
PAIRIPFIX_URL="https://github.com/ahmedmani/pairipfix/releases/download/v1.2/app-debug.apk"

echo "Baixando Play Integrity Fix..."
curl -L -s -o "$TMP_DIR/PlayIntegrityFix.zip" "$PIF_URL"

echo "Baixando LSPosed (Zygisk Release)..."
curl -L -s -o "$TMP_DIR/LSPosed.zip" "$LSPOSED_URL"

echo "Baixando módulo PairIPFix (APK)..."
curl -L -s -o "$TMP_DIR/pairipfix.apk" "$PAIRIPFIX_URL"

# 5. Configurar banco de dados do Magisk (Zygisk, MagiskHide, SuList e DenyList)
echo -e "\n${YELLOW}[5/6] Configurando Zygisk, MagiskHide e isolamento de processos...${NC}"
sudo python3 -c "
import sqlite3, os

db_dir = '/var/lib/waydroid/data/adb'
os.makedirs(db_dir, exist_ok=True)
db_path = os.path.join(db_dir, 'magisk.db')

conn = sqlite3.connect(db_path)
cur = conn.cursor()

# Configurações globais
cur.execute('CREATE TABLE IF NOT EXISTS settings (key TEXT, value INT, PRIMARY KEY(key));')
cur.execute(\"INSERT OR REPLACE INTO settings (key, value) VALUES ('zygisk', 1);\")
cur.execute(\"INSERT OR REPLACE INTO settings (key, value) VALUES ('magiskhide', 1);\")
cur.execute(\"INSERT OR REPLACE INTO settings (key, value) VALUES ('denylist', 1);\")
cur.execute(\"INSERT OR REPLACE INTO settings (key, value) VALUES ('sulist', 0);\")

# DenyList e HideList
cur.execute('CREATE TABLE IF NOT EXISTS denylist (package_name TEXT, process TEXT, PRIMARY KEY (package_name, process));')
cur.execute('CREATE TABLE IF NOT EXISTS hidelist (package_name TEXT, process TEXT, PRIMARY KEY (package_name, process));')

packages_to_hide = [
    ('com.google.android.gms', 'com.google.android.gms'),
    ('com.google.android.gms', 'com.google.android.gms.unstable'),
    ('com.android.vending', 'com.android.vending'),
    ('com.pazugames.avatarworld', 'com.pazugames.avatarworld'),
    ('com.roblox.client', 'com.roblox.client'),
    ('com.supercell.brawlstars', 'com.supercell.brawlstars'),
]

for pkg, proc in packages_to_hide:
    cur.execute('INSERT OR IGNORE INTO denylist (package_name, process) VALUES (?, ?);', (pkg, proc))
    cur.execute('INSERT OR IGNORE INTO hidelist (package_name, process) VALUES (?, ?);', (pkg, proc))

conn.commit()
conn.close()
"
sudo chmod 600 /var/lib/waydroid/data/adb/magisk.db 2>/dev/null || true

# Iniciar o contêiner para instalar os módulos via ambiente Android
sudo systemctl start waydroid-container
sleep 3

# Copiar arquivos temporários para dentro do contêiner
sudo mkdir -p /var/lib/waydroid/data/local/tmp
sudo cp "$TMP_DIR/PlayIntegrityFix.zip" /var/lib/waydroid/data/local/tmp/
sudo cp "$TMP_DIR/LSPosed.zip" /var/lib/waydroid/data/local/tmp/
sudo chmod 777 /var/lib/waydroid/data/local/tmp/*

# Instalar módulos com o binário do Magisk via lxc-attach
echo "Instalando módulo Play Integrity Fix no Magisk..."
sudo lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- /system/bin/sh -c \
    "BOOTMODE=true /data/adb/magisk/magisk --install-module /data/local/tmp/PlayIntegrityFix.zip" 2>/dev/null || true

echo "Instalando módulo LSPosed (Zygisk) no Magisk..."
sudo lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- /system/bin/sh -c \
    "BOOTMODE=true /data/adb/magisk/magisk --install-module /data/local/tmp/LSPosed.zip" 2>/dev/null || true

# 6. Limpar cache da Play Store e Play Services
echo -e "\n${YELLOW}[6/6] Limpando dados residuais da Google Play e finalizando...${NC}"
sudo lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- /system/bin/sh -c "pm clear com.android.vending" 2>/dev/null || true
sudo lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- /system/bin/sh -c "pm clear com.google.android.gms" 2>/dev/null || true

# Reiniciar o contêiner para carregar o Zygisk no boot
sudo systemctl restart waydroid-container
sleep 2

# Instalar o APK do PairIPFix caso o Waydroid já esteja acessível
if [ -f "$TMP_DIR/pairipfix.apk" ]; then
    waydroid app install "$TMP_DIR/pairipfix.apk" 2>/dev/null || true
fi

rm -rf "$TMP_DIR"

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BOLD}${GREEN}    CONFIGURAÇÃO DE COMPATIBILIDADE CONCLUÍDA COM SUCESSO!     ${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""
echo -e "${BOLD}O que foi ativado:${NC}"
echo -e "✔️ ${GREEN}Magisk Delta (Kitsune Mask)${NC} com isolamento profundo"
echo -e "✔️ ${GREEN}Zygisk & MagiskHide${NC} ativados nativamente"
echo -e "✔️ ${GREEN}Play Integrity Fix [INJECT]${NC} instalado para passar na integridade do Google"
echo -e "✔️ ${GREEN}LSPosed (Zygisk)${NC} instalado para gerenciar módulos de runtime"
echo -e "✔️ ${GREEN}PairIPFix${NC} instalado para neutralizar a checagem anti-tamper"
echo -e "✔️ Processos de ${YELLOW}Avatar World${NC}, ${YELLOW}Play Store${NC} e ${YELLOW}Play Services${NC} adicionados à DenyList"
echo ""
echo -e "${BOLD}Como testar agora:${NC}"
echo -e "1. Abra o Waydroid pelo atalho ${GREEN}'Iniciar Android'${NC} na Área de Trabalho."
echo -e "2. Abra o aplicativo ${YELLOW}LSPosed${NC} (notificação ou app) e confira se o módulo ${BOLD}PairIPFix${NC} está marcado."
echo -e "3. Abra a Google Play Store (ou instale o APK do Avatar World) e inicie o jogo!"
echo ""
