#!/bin/bash
# ==============================================================================
# Script de Compatibilidade 100% Automatizada Anti-Tamper / PairIP (Waydroid)
# Repositório: https://github.com/marquimRcc/android-regataos-linux
# Branch: feature/magisk-play-integrity
# ==============================================================================
# Totalmente silencioso e pré-configurado:
# - Instala Magisk Delta (Kitsune Mask)
# - Ativa Zygisk e MagiskHide nativamente no banco de dados
# - Injeta Play Integrity Fix diretamente nos módulos
# - Injeta LSPosed Framework (Zygisk) diretamente nos módulos
# - Ativa o PairIPFix no banco de dados do LSPosed (com escopo no Avatar World)
# - O usuário final só abre o jogo e joga!
# ==============================================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${BLUE}================================================================${NC}"
echo -e "${BOLD}${GREEN}  Desbloqueio Automático: Avatar World & Anti-Tamper (Waydroid) ${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# 1. Privilégios sudo
echo -e "${YELLOW}[1/5] Verificando privilégios de administrador (sudo)...${NC}"
if ! sudo -v; then
    echo -e "${RED}Erro: Senha incorreta ou permissão recusada.${NC}"
    exit 1
fi

while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &

# 2. Encerrar Waydroid para aplicar injeções no sistema de arquivos
echo -e "\n${YELLOW}[2/5] Parando serviços do Waydroid para injeção limpa...${NC}"
waydroid session stop 2>/dev/null || true
sudo systemctl stop waydroid-container 2>/dev/null || true
sleep 2

# 3. Verificar e Configurar Magisk Delta se necessário
echo -e "\n${YELLOW}[3/5] Verificando Magisk Delta no Android...${NC}"
if [ ! -d "/var/lib/waydroid/overlay/system/etc/init/magisk" ]; then
    echo "Instalando base do Magisk Delta..."
    SCRIPT_DIR="$HOME/waydroid_script"

    if [ ! -d "$SCRIPT_DIR" ]; then
        echo "Baixando script utilitário do Waydroid..."
        mkdir -p "$SCRIPT_DIR"
        curl -L -s https://github.com/casualsnek/waydroid_script/archive/refs/heads/main.tar.gz | tar -xz --strip-components=1 -C "$SCRIPT_DIR"
    fi

    if [ ! -d "$SCRIPT_DIR/venv" ]; then
        echo "Criando ambiente virtual Python..."
        python3 -m venv "$SCRIPT_DIR/venv"
        "$SCRIPT_DIR/venv/bin/pip" install --quiet -r "$SCRIPT_DIR/requirements.txt"
    fi

    cd "$SCRIPT_DIR"
    sudo "$SCRIPT_DIR/venv/bin/python3" main.py install magisk
else
    echo -e "${GREEN}Base do Magisk Delta já está instalada! Pulando etapa redundante...${NC}"
fi

# 4. Injeção direta e pré-configuração (Zygisk, Play Integrity Fix, LSPosed, PairIPFix)
echo -e "\n${YELLOW}[4/5] Injetando e ativando módulos automaticamente (Zygisk + LSPosed + PIF)...${NC}"
sudo python3 -c "
import zipfile, io, os, shutil, sqlite3, urllib.request

user = os.environ.get('SUDO_USER', os.environ.get('USER', 'pcmini'))
target_dirs = [
    f'/home/{user}/.local/share/waydroid/data',
    '/var/lib/waydroid/data'
]

# Baixar PIF
print('  -> Baixando Play Integrity Fix...')
pif_url = 'https://github.com/KOWX712/PlayIntegrityFix/releases/download/v4.9-inject-s/PlayIntegrityFix_v4.9-inject-s.zip'
req = urllib.request.Request(pif_url, headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req) as resp:
    pif_zip_data = resp.read()

# Baixar LSPosed
print('  -> Baixando LSPosed Framework (Zygisk)...')
lsp_url = 'https://github.com/mywalkb/LSPosed_mod/releases/download/v1.9.3_mod/LSPosed-v1.9.3_mod-7244-zygisk-release.zip'
req = urllib.request.Request(lsp_url, headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req) as resp:
    lsp_zip_data = resp.read()

for base_dir in target_dirs:
    if not os.path.exists(base_dir):
        continue
    
    adb_dir = os.path.join(base_dir, 'adb')
    modules_dir = os.path.join(adb_dir, 'modules')
    os.makedirs(modules_dir, exist_ok=True)

    # 4.1 Configurar magisk.db com Zygisk ativado por padrão
    db_path = os.path.join(adb_dir, 'magisk.db')
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute('CREATE TABLE IF NOT EXISTS settings (key TEXT, value INT, PRIMARY KEY(key));')
    cur.execute(\"INSERT OR REPLACE INTO settings (key, value) VALUES ('zygisk', 1);\")
    cur.execute(\"INSERT OR REPLACE INTO settings (key, value) VALUES ('magiskhide', 1);\")
    cur.execute(\"INSERT OR REPLACE INTO settings (key, value) VALUES ('denylist', 1);\")
    cur.execute(\"INSERT OR REPLACE INTO settings (key, value) VALUES ('sulist', 0);\")

    cur.execute('CREATE TABLE IF NOT EXISTS denylist (package_name TEXT, process TEXT, PRIMARY KEY (package_name, process));')
    cur.execute('CREATE TABLE IF NOT EXISTS hidelist (package_name TEXT, process TEXT, PRIMARY KEY (package_name, process));')
    for pkg, proc in [
        ('com.google.android.gms', 'com.google.android.gms'),
        ('com.google.android.gms', 'com.google.android.gms.unstable'),
        ('com.android.vending', 'com.android.vending'),
        ('com.pazugames.avatarworld', 'com.pazugames.avatarworld'),
        ('com.roblox.client', 'com.roblox.client'),
        ('com.supercell.brawlstars', 'com.supercell.brawlstars')
    ]:
        cur.execute('INSERT OR IGNORE INTO denylist (package_name, process) VALUES (?, ?);', (pkg, proc))
        cur.execute('INSERT OR IGNORE INTO hidelist (package_name, process) VALUES (?, ?);', (pkg, proc))
    conn.commit()
    conn.close()
    try:
        os.chmod(db_path, 0o600)
    except Exception:
        pass

    # 4.2 Injetar Play Integrity Fix
    pif_mod_dir = os.path.join(modules_dir, 'playintegrityfix')
    os.makedirs(pif_mod_dir, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(pif_zip_data)) as z_pif:
        z_pif.extractall(pif_mod_dir)
    open(os.path.join(pif_mod_dir, 'auto_mount'), 'w').close()
    for root, dirs, files in os.walk(pif_mod_dir):
        for f in files:
            if f.endswith('.sh'):
                try:
                    os.chmod(os.path.join(root, f), 0o755)
                except Exception:
                    pass

    # 4.3 Injetar LSPosed Zygisk
    lsp_mod_dir = os.path.join(modules_dir, 'zygisk_lsposed')
    os.makedirs(lsp_mod_dir, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(lsp_zip_data)) as z_lsp:
        for fname in ['module.prop', 'post-fs-data.sh', 'service.sh', 'sepolicy.rule', 'system.prop', 'daemon', 'daemon.apk', 'manager.apk']:
            if fname in z_lsp.namelist():
                z_lsp.extract(fname, lsp_mod_dir)
        
        os.makedirs(os.path.join(lsp_mod_dir, 'framework'), exist_ok=True)
        if 'framework/lspd.dex' in z_lsp.namelist():
            with z_lsp.open('framework/lspd.dex') as src, open(os.path.join(lsp_mod_dir, 'framework', 'lspd.dex'), 'wb') as dst:
                dst.write(src.read())

        zygisk_dir = os.path.join(lsp_mod_dir, 'zygisk')
        os.makedirs(zygisk_dir, exist_ok=True)
        arch_map = {
            'lib/x86_64/liblspd.so': 'x86_64.so',
            'lib/x86/liblspd.so': 'x86.so',
            'lib/arm64-v8a/liblspd.so': 'arm64-v8a.so',
            'lib/armeabi-v7a/liblspd.so': 'armeabi-v7a.so'
        }
        for src_path, dst_name in arch_map.items():
            if src_path in z_lsp.namelist():
                with z_lsp.open(src_path) as src, open(os.path.join(zygisk_dir, dst_name), 'wb') as dst:
                    dst.write(src.read())

        for bin_path in ['bin/x86_64/dex2oat', 'bin/arm64-v8a/dex2oat', 'bin/armeabi-v7a/dex2oat', 'bin/x86/dex2oat']:
            if bin_path in z_lsp.namelist():
                target_bin = os.path.join(lsp_mod_dir, bin_path)
                os.makedirs(os.path.dirname(target_bin), exist_ok=True)
                with z_lsp.open(bin_path) as src, open(target_bin, 'wb') as dst:
                    dst.write(src.read())
                try:
                    os.chmod(target_bin, 0o755)
                except Exception:
                    pass

    open(os.path.join(lsp_mod_dir, 'auto_mount'), 'w').close()
    for f in ['post-fs-data.sh', 'service.sh', 'daemon']:
        p = os.path.join(lsp_mod_dir, f)
        if os.path.exists(p):
            try:
                os.chmod(p, 0o755)
            except Exception:
                pass

    # 4.4 Pré-configurar banco do LSPosed com PairIPFix já ativado e com Avatar World no escopo
    lspd_config_dir = os.path.join(adb_dir, 'lspd', 'config')
    os.makedirs(lspd_config_dir, exist_ok=True)
    db_lsp = os.path.join(lspd_config_dir, 'modules_config.db')
    conn_lsp = sqlite3.connect(db_lsp)
    c_lsp = conn_lsp.cursor()
    c_lsp.execute('CREATE TABLE IF NOT EXISTS modules (mid INTEGER PRIMARY KEY AUTOINCREMENT, module_pkg_name TEXT UNIQUE, apk_path TEXT, enabled INTEGER, auto_include INTEGER);')
    c_lsp.execute('CREATE TABLE IF NOT EXISTS scope (mid INTEGER, app_pkg_name TEXT, user_id INTEGER, PRIMARY KEY (mid, app_pkg_name, user_id));')
    c_lsp.execute(\"INSERT OR REPLACE INTO modules (mid, module_pkg_name, apk_path, enabled, auto_include) VALUES (1, 'com.android.pairipfix', '', 1, 1);\")
    for app in ['com.pazugames.avatarworld', 'com.roblox.client', 'com.supercell.brawlstars']:
        c_lsp.execute(\"INSERT OR IGNORE INTO scope (mid, app_pkg_name, user_id) VALUES (1, ?, 0);\", (app,))
    conn_lsp.commit()
    conn_lsp.close()
    try:
        os.chmod(db_lsp, 0o600)
    except Exception:
        pass

print('  -> Injeção concluída com sucesso em todas as árvores do contêiner!')
"

# 5. Baixar e instalar APKs complementares (PairIPFix e LSPosed Manager)
echo -e "\n${YELLOW}[5/5] Instalando aplicativos de controle e finalizando...${NC}"
sudo systemctl start waydroid-container
sleep 3

TMP_APKS="/tmp/waydroid_install_apks"
mkdir -p "$TMP_APKS"

# Extrair manager.apk do LSPosed para acesso visual
USER_DATA="/home/${SUDO_USER:-$USER}/.local/share/waydroid/data"
[ ! -d "$USER_DATA" ] && USER_DATA="/var/lib/waydroid/data"
if [ -f "$USER_DATA/adb/modules/zygisk_lsposed/manager.apk" ]; then
    cp "$USER_DATA/adb/modules/zygisk_lsposed/manager.apk" "$TMP_APKS/lsposed_manager.apk"
fi

# Baixar PairIPFix APK
curl -L -s -o "$TMP_APKS/pairipfix.apk" "https://github.com/ahmedmani/pairipfix/releases/download/v1.2/app-debug.apk" || true

# Instalar no Android
[ -f "$TMP_APKS/lsposed_manager.apk" ] && waydroid app install "$TMP_APKS/lsposed_manager.apk" 2>/dev/null || true
[ -f "$TMP_APKS/pairipfix.apk" ] && waydroid app install "$TMP_APKS/pairipfix.apk" 2>/dev/null || true

# Resetar dados da Play Store e Play Services para renovar atestação
sudo lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- /system/bin/sh -c "pm clear com.android.vending" 2>/dev/null || true
sudo lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- /system/bin/sh -c "pm clear com.google.android.gms" 2>/dev/null || true

rm -rf "$TMP_APKS"

# Reiniciar o contêiner para que o Zygisk e o LSPosed subam ativos no boot do Android
sudo systemctl restart waydroid-container
sleep 2

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BOLD}${GREEN}  TUDO 100% CONFIGURADO E PRONTO AUTOMATICAMENTE!               ${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""
echo -e "✔️ ${GREEN}Zygisk & MagiskHide${NC} ativados na inicialização do sistema"
echo -e "✔️ ${GREEN}Play Integrity Fix${NC} ativado para certificação da Play Store"
echo -e "✔️ ${GREEN}LSPosed Framework${NC} ativado nativamente"
echo -e "✔️ ${GREEN}PairIPFix${NC} pré-ativado com suporte automático para o ${BOLD}Avatar World${NC}"
echo ""
echo -e "${BOLD}O que você precisa fazer agora:${NC}"
echo -e "1. Abra o ${GREEN}Iniciar Android (Waydroid)${NC} na Área de Trabalho."
echo -e "2. Abra a ${YELLOW}Google Play Store${NC} com a sua conta Google."
echo -e "3. Baixe e instale o ${BOLD}Avatar World${NC}."
echo -e "4. Jogue à vontade! Ele vai abrir normalmente."
echo ""
