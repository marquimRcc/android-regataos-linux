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
echo -e "${YELLOW}[1/8] Verificando privilégios de administrador (sudo)...${NC}"
if ! sudo -v; then
    echo -e "${RED}Erro: Senha incorreta ou permissão recusada.${NC}"
    read -p "Pressione [Enter] para fechar..."
    exit 1
fi

# Manter sudo vivo durante a execução do script
while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &

# 2. Configurar parâmetro de kernel psi=1 (Pressure Stall Information - Essencial para o Android não fechar)
echo -e "\n${YELLOW}[2/8] Verificando configuração do Kernel (psi=1)...${NC}"
NEED_REBOOT=0
if ! grep -q "psi=1" /etc/default/grub 2>/dev/null; then
    echo "Habilitando psi=1 no GRUB para o Android..."
    sudo python3 -c "
with open('/etc/default/grub', 'r') as f:
    text = f.read()
import re
if 'psi=1' not in text:
    new_text = re.sub(r'(GRUB_CMDLINE_LINUX_DEFAULT=[\'\"])', r'\g<1>psi=1 ', text)
    with open('/etc/default/grub', 'w') as f:
        f.write(new_text)
"
    echo "Atualizando inicializador do sistema (grub2-mkconfig)..."
    sudo /usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg
    NEED_REBOOT=1
else
    echo -e "${GREEN}Parâmetro psi=1 já configurado no GRUB!${NC}"
fi

if [ ! -f /proc/pressure/cpu ]; then
    NEED_REBOOT=1
fi

# 3. Instalar dependências base do sistema
echo -e "\n${YELLOW}[3/8] Instalando dependências do sistema via zypper...${NC}"
sudo zypper --non-interactive install --no-recommends \
    lxc \
    python313-gobject \
    python313-pyclipper \
    python313-gbinder \
    dnsmasq \
    curl \
    tar \
    xclip

# 4. Baixar e instalar o Waydroid (contornando falso conflito de versão do repositório)
echo -e "\n${YELLOW}[4/8] Instalando pacote Waydroid oficial...${NC}"
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

# 5. Atualizar libgbinder1 (garante compatibilidade com Python 3.13)
echo -e "\n${YELLOW}[5/8] Verificando biblioteca libgbinder1...${NC}"
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

# 5.1 Instalar módulo gbinder corrigido para Python 3.13 e configurar dnsmasq
echo -e "\n${YELLOW}[5.1] Configurando módulo gbinder e rotas de rede...${NC}"
SCRIPT_BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -f "$SCRIPT_BASE_DIR/assets/gbinder.cpython-313-x86_64-linux-gnu.so" ]; then
    sudo cp -f "$SCRIPT_BASE_DIR/assets/gbinder.cpython-313-x86_64-linux-gnu.so" /usr/lib64/python3.13/site-packages/
else
    sudo curl -L -s -o /usr/lib64/python3.13/site-packages/gbinder.cpython-313-x86_64-linux-gnu.so \
        "https://raw.githubusercontent.com/marquimRcc/android-regataos-linux/main/assets/gbinder.cpython-313-x86_64-linux-gnu.so"
fi
mkdir -p "$HOME/.local/lib/python3.13/site-packages"
cp -f /usr/lib64/python3.13/site-packages/gbinder.cpython-313-x86_64-linux-gnu.so "$HOME/.local/lib/python3.13/site-packages/" 2>/dev/null || true
sudo ln -sf /usr/sbin/dnsmasq /usr/bin/dnsmasq

# 5.2 Configurar Firewall para permitir DHCP e Internet no Waydroid
echo -e "\n${YELLOW}[5.2] Configurando Firewall para liberação da rede e internet...${NC}"
if command -v firewall-cmd &>/dev/null; then
    sudo firewall-cmd --zone=trusted --add-interface=waydroid0 --permanent 2>/dev/null || true
    sudo firewall-cmd --add-masquerade --permanent 2>/dev/null || true
    sudo firewall-cmd --reload 2>/dev/null || true
fi
sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true

# 6. Habilitar serviço do contêiner e inicializar a imagem do Android
echo -e "\n${YELLOW}[6/8] Configurando contêiner e imagens do sistema...${NC}"
sudo systemctl enable --now waydroid-container

if [ ! -f /var/lib/waydroid/images/system.img ]; then
    echo -e "${BLUE}Baixando imagem oficial do Android GAPPS (Google Play Store)...${NC}"
    echo "Isso pode levar alguns minutos (download de ~1GB)..."
    sudo waydroid init -s GAPPS
else
    echo -e "${GREEN}Imagens do Android já estão instaladas!${NC}"
fi

# 7. Configurar traduções ARM (libndk) para permitir rodar jogos e aplicativos de celular
echo -e "\n${YELLOW}[7/8] Configurando suporte para jogos e apps ARM (libndk)...${NC}"
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

# Verificar se o Magisk Delta (Kitsune Mask) já está configurado no overlay
if [ ! -d "/var/lib/waydroid/overlay/system/etc/init/magisk" ]; then
    echo "Instalando Magisk Delta (Kitsune Mask) com isolamento avançado..."
    cd "$SCRIPT_DIR"
    sudo "$SCRIPT_DIR/venv/bin/python3" main.py install magisk
else
    echo -e "${GREEN}Magisk Delta já configurado!${NC}"
fi

# 7.1 Configurar perfil de dispositivo homologado (Google Pixel 6 Pro) para Play Store automática
echo -e "\n${YELLOW}[7.1] Aplicando perfil de dispositivo homologado (Google Pixel 6 Pro)...${NC}"
sudo python3 -c "
import configparser
cfg_path = '/var/lib/waydroid/waydroid.cfg'
config = configparser.ConfigParser()
config.read(cfg_path)
if 'properties' not in config:
    config['properties'] = {}

pixel_props = {
    # Identidade Base Google Pixel 6 Pro
    'ro.product.brand': 'google',
    'ro.product.manufacturer': 'Google',
    'ro.product.device': 'raven',
    'ro.product.name': 'raven',
    'ro.product.model': 'Pixel 6 Pro',

    # Build Tags e Tipo (Ocultar test-keys e userdebug de TODAS as particoes)
    'ro.build.tags': 'release-keys',
    'ro.build.type': 'user',
    'ro.system.build.tags': 'release-keys',
    'ro.system.build.type': 'user',
    'ro.system_ext.build.tags': 'release-keys',
    'ro.system_ext.build.type': 'user',
    'ro.vendor.build.tags': 'release-keys',
    'ro.vendor.build.type': 'user',
    'ro.odm.build.tags': 'release-keys',
    'ro.odm.build.type': 'user',
    'ro.vendor_dlkm.build.tags': 'release-keys',
    'ro.vendor_dlkm.build.type': 'user',

    # Identidade Completa por Particao (Ocultar waydroid_x86_64 contra anti-tamper)
    'ro.product.system.brand': 'Google',
    'ro.product.system.device': 'raven',
    'ro.product.system.name': 'raven',
    'ro.product.system.model': 'Pixel 6 Pro',
    'ro.product.system.manufacturer': 'Google',

    'ro.product.system_ext.brand': 'Google',
    'ro.product.system_ext.device': 'raven',
    'ro.product.system_ext.name': 'raven',
    'ro.product.system_ext.model': 'Pixel 6 Pro',
    'ro.product.system_ext.manufacturer': 'Google',

    'ro.product.vendor.brand': 'Google',
    'ro.product.vendor.device': 'raven',
    'ro.product.vendor.name': 'raven',
    'ro.product.vendor.model': 'Pixel 6 Pro',
    'ro.product.vendor.manufacturer': 'Google',

    'ro.product.odm.brand': 'Google',
    'ro.product.odm.device': 'raven',
    'ro.product.odm.name': 'raven',
    'ro.product.odm.model': 'Pixel 6 Pro',
    'ro.product.odm.manufacturer': 'Google',

    'ro.product.vendor_dlkm.brand': 'Google',
    'ro.product.vendor_dlkm.device': 'raven',
    'ro.product.vendor_dlkm.name': 'raven',
    'ro.product.vendor_dlkm.model': 'Pixel 6 Pro',
    'ro.product.vendor_dlkm.manufacturer': 'Google',

    # Fingerprints sincronizados em 100% das particoes
    'ro.build.display.id': 'TQ3A.230901.001',
    'ro.build.description': 'raven-user 13 TQ3A.230901.001 10750268 release-keys',
    'ro.system.build.flavor': 'raven-user',
    'ro.build.flavor': 'raven-user',
    'ro.build.fingerprint': 'google/raven/raven:13/TQ3A.230901.001/10750268:user/release-keys',
    'ro.bootimage.build.fingerprint': 'google/raven/raven:13/TQ3A.230901.001/10750268:user/release-keys',
    'ro.system.build.fingerprint': 'google/raven/raven:13/TQ3A.230901.001/10750268:user/release-keys',
    'ro.system_ext.build.fingerprint': 'google/raven/raven:13/TQ3A.230901.001/10750268:user/release-keys',
    'ro.vendor.build.fingerprint': 'google/raven/raven:13/TQ3A.230901.001/10750268:user/release-keys',
    'ro.odm.build.fingerprint': 'google/raven/raven:13/TQ3A.230901.001/10750268:user/release-keys',
    'ro.product.build.fingerprint': 'google/raven/raven:13/TQ3A.230901.001/10750268:user/release-keys',
    'ro.vendor_dlkm.build.fingerprint': 'google/raven/raven:13/TQ3A.230901.001/10750268:user/release-keys',
    'ro.vendor.build.id': 'TQ3A.230901.001',

    # Modo multi-janelas
    'persist.waydroid.multi_windows': 'true'
}

for k, v in pixel_props.items():
    config['properties'][k] = v

with open(cfg_path, 'w') as f:
    config.write(f)
"
sudo waydroid upgrade -o 2>/dev/null || true

# 7.2 Configurar Suporte a Anti-Tamper e PairIP (Avatar World, Roblox, Supercell)
echo -e "\n${YELLOW}[7.2] Configurando Zygisk, Play Integrity Fix e PairIPFix...${NC}"
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

    # 1. Configurar magisk.db com Zygisk ativado por padrão
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

    # 2. Injetar Play Integrity Fix
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

    # 3. Injetar LSPosed Zygisk
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

    # 4. Pré-configurar banco do LSPosed com PairIPFix já ativado e com Avatar World no escopo
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
"

# 7.3 Instalar loja alternativa Aurora Store (sem necessidade de conta ou certificação)
echo -e "\n${YELLOW}[7.3] Baixando loja complementar Aurora Store (FOSS)...${NC}"
AURORA_APK="/tmp/AuroraStore.apk"
curl -L -s -o "$AURORA_APK" "https://auroraoss.com/downloads/AuroraStore/Release/preload/AuroraStore-preload-4.7.5.apk" || true
if [ -f "$AURORA_APK" ] && [ -s "$AURORA_APK" ]; then
    echo "Instalando Aurora Store no Waydroid..."
    waydroid app install "$AURORA_APK" 2>/dev/null || true
    rm -f "$AURORA_APK"
fi

if [ -f "$TMP_DIR/LSPosed.zip" ]; then
    unzip -p "$TMP_DIR/LSPosed.zip" manager.apk > "$TMP_DIR/lsposed_manager.apk" 2>/dev/null || true
    if [ -f "$TMP_DIR/lsposed_manager.apk" ]; then
        echo "Instalando Gerenciador LSPosed no Waydroid..."
        waydroid app install "$TMP_DIR/lsposed_manager.apk" 2>/dev/null || true
    fi
fi

if [ -f "$TMP_DIR/pairipfix.apk" ]; then
    echo "Instalando módulo PairIPFix no Waydroid..."
    waydroid app install "$TMP_DIR/pairipfix.apk" 2>/dev/null || true
fi
rm -rf "$TMP_DIR"

# Resetar dados da Play Store e GMS para aplicar novas assinaturas
sudo waydroid shell pm clear com.android.vending 2>/dev/null || true
sudo waydroid shell pm clear com.google.android.gms 2>/dev/null || true

# 8. Otimizações de Desempenho e Usabilidade Pós-Instalação
echo -e "\n${YELLOW}[8/8] Aplicando otimizações de desempenho e atalhos...${NC}"

# 8.1 Otimização de latência do cursor no Wayland
sudo waydroid prop set persist.waydroid.cursor_on_subsurface true 2>/dev/null || true

# 8.2 Instalação com 2 cliques ou botão direito para arquivos .APK
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

# 8.3 Script utilitário para certificação da Play Store
mkdir -p "$HOME/.local/bin"
cat << 'EOF' > "$HOME/.local/bin/waydroid-cert"
#!/bin/bash
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${BLUE}================================================================${NC}"
echo -e "${BOLD}${GREEN}        Certificação da Google Play Store (Waydroid)            ${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

echo -e "${YELLOW}Buscando ID de certificação do Google Services Framework...${NC}"
echo "Digite sua senha de administrador caso solicitado:"

ANDROID_ID=""

if [ -f "$HOME/waydroid_script/main.py" ]; then
    ANDROID_ID=$(sudo "$HOME/waydroid_script/venv/bin/python3" "$HOME/waydroid_script/main.py" certified 2>/dev/null | grep -oE '[0-9]{15,20}' | head -n 1)
fi

if [ -z "$ANDROID_ID" ]; then
    ANDROID_ID=$(sudo waydroid shell 'sqlite3 /data/data/com.google.android.gsf/databases/gservices.db "select value from main where name = \"android_id\";"' 2>/dev/null | grep -oE '[0-9]{15,20}' | head -n 1)
fi

if [ -z "$ANDROID_ID" ]; then
    ANDROID_ID=$(sudo waydroid shell 'sqlite3 /data/data/com.google.android.gsf/databases/gservices.db "select * from main where name = \"android_id\";"' 2>/dev/null | tr -d '\r\n' | sed 's/.*|//')
fi

if [ -n "$ANDROID_ID" ]; then
    echo ""
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${BOLD}ID do seu Android:${NC} ${YELLOW}$ANDROID_ID${NC}"
    echo -e "${GREEN}================================================================${NC}"
    
    if command -v wl-copy &>/dev/null; then
        echo -n "$ANDROID_ID" | wl-copy 2>/dev/null
        echo -e "${GREEN}✔️  ID copiado automaticamente para a sua área de transferência (Ctrl+V)!${NC}"
    elif command -v xclip &>/dev/null; then
        echo -n "$ANDROID_ID" | xclip -selection clipboard 2>/dev/null
        echo -e "${GREEN}✔️  ID copiado automaticamente para a sua área de transferência (Ctrl+V)!${NC}"
    fi
    
    echo -e "\nAbrindo a página oficial da Google no seu navegador..."
    xdg-open "https://www.google.com/android/uncertified/" 2>/dev/null &
    
    echo ""
    echo -e "${BOLD}Instruções:${NC}"
    echo "1. Na página do Google que abriu, faça login com sua conta."
    echo "2. Cole (Ctrl+V) o número no campo 'ID do Google Services Framework'."
    echo "3. Clique no botão 'Registrar'."
    echo ""
    read -p "Após clicar em 'Registrar' no site, pressione [Enter] aqui para resetar o cache da Play Store..."
    
    echo -e "\n${YELLOW}Limpando cache da Play Store e aplicando liberação...${NC}"
    sudo waydroid shell pm clear com.android.vending 2>/dev/null || true
    sudo waydroid shell pm clear com.google.android.gms 2>/dev/null || true
    
    echo -e "\n${GREEN}${BOLD}✔️  Tudo pronto!${NC}"
    echo -e "Agora você já pode abrir a Google Play Store e entrar normalmente com seu e-mail e senha."
else
    echo -e "${RED}Não foi possível obter o ID automaticamente.${NC}"
    echo "Certifique-se de que o Waydroid já foi iniciado pelo menos uma vez."
fi

echo ""
read -p "Pressione [Enter] para fechar..."
EOF
chmod +x "$HOME/.local/bin/waydroid-cert"

# 8.4 Integração Nativa de Desinstalação com Botão Direito no Menu (KDE Plasma)
echo -e "\n${YELLOW}[8.4] Configurando desinstalação gráfica com botão direito para aplicativos...${NC}"

# Script auxiliar executado pelo sistema para remoção limpa
sudo tee /usr/local/bin/waydroid-uninstall-helper > /dev/null << 'EOF'
#!/bin/bash
PACKAGE="$1"
[ -z "$PACKAGE" ] && exit 1

if ! systemctl is-active --quiet waydroid-container; then
    systemctl start waydroid-container
    sleep 1
fi

lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- /system/bin/sh -c "pm uninstall $PACKAGE" 2>/dev/null || \
waydroid shell pm uninstall "$PACKAGE" 2>/dev/null
EOF
sudo chmod 755 /usr/local/bin/waydroid-uninstall-helper

# Regra de sudoers para permitir desinstalação segura e transparente sem pedir senha
echo "ALL ALL=(ALL) NOPASSWD: /usr/local/bin/waydroid-uninstall-helper" | sudo tee /etc/sudoers.d/waydroid-uninstall > /dev/null
sudo chmod 440 /etc/sudoers.d/waydroid-uninstall

# Script principal do desinstalador gráfico (interface KDE Plasma / kdialog)
sudo tee /usr/local/bin/waydroid-uninstall > /dev/null << 'EOF'
#!/bin/bash
PACKAGE="$1"
APP_NAME="$2"

[ -z "$PACKAGE" ] && exit 1
[ -z "$APP_NAME" ] && APP_NAME="$PACKAGE"

# 1. Confirmação nativa do KDE Plasma
if command -v kdialog &>/dev/null; then
    kdialog --title "Desinstalar Aplicativo" \
            --yesno "Deseja realmente desinstalar <b>$APP_NAME</b> do seu sistema?" \
            --icon "edit-delete"
    [ $? -ne 0 ] && exit 0
fi

# 2. Executa a desinstalação no Android
if sudo -n /usr/local/bin/waydroid-uninstall-helper "$PACKAGE" 2>/dev/null; then
    STATUS=0
elif command -v pkexec &>/dev/null; then
    pkexec /usr/local/bin/waydroid-uninstall-helper "$PACKAGE"
    STATUS=$?
else
    STATUS=1
fi

# 3. Remove atalhos .desktop locais
rm -f "$HOME/.local/share/applications/waydroid.$PACKAGE.desktop"
rm -f "$HOME/Área de trabalho/waydroid.$PACKAGE.desktop"
rm -f "$HOME/Desktop/waydroid.$PACKAGE.desktop"
rm -f "$HOME/Área de trabalho/$APP_NAME.desktop"
rm -f "$HOME/Desktop/$APP_NAME.desktop"

# 4. Notificação visual de sucesso
if command -v kdialog &>/dev/null; then
    kdialog --title "Desinstalar Aplicativo" \
            --passivepopup "O aplicativo <b>$APP_NAME</b> foi desinstalado com sucesso!" 4 \
            --icon "dialog-ok-apply"
fi
EOF
sudo chmod 755 /usr/local/bin/waydroid-uninstall

# Patch no gerador do Waydroid para que todos os novos apps já venham com o botão direito configurado
sudo python3 -c "
path = '/usr/lib/waydroid/tools/services/user_manager.py'
try:
    with open(path, 'r') as f:
        code = f.read()
    if 'Desktop Action uninstall' not in code:
        target = 'glib_key_file_prepend_string_list(desktop_file, \"Desktop Entry\", \"Actions\", [\"app-settings\"])'
        replacement = '''glib_key_file_prepend_string_list(desktop_file, \"Desktop Entry\", \"Actions\", [\"uninstall\", \"app-settings\"])
        desktop_file.set_string(\"Desktop Action uninstall\", \"Name\", \"Desinstalar aplicativo\")
        desktop_file.set_string(\"Desktop Action uninstall\", \"Name[pt_BR]\", \"Desinstalar aplicativo\")
        desktop_file.set_string(\"Desktop Action uninstall\", \"Name[en]\", \"Uninstall application\")
        desktop_file.set_string(\"Desktop Action uninstall\", \"Exec\", f\"/usr/local/bin/waydroid-uninstall {packageName} \\\"{appInfo['name']}\\\"\")
        desktop_file.set_string(\"Desktop Action uninstall\", \"Icon\", \"edit-delete\")'''
        if target in code:
            code = code.replace(target, replacement)
            with open(path, 'w') as f:
                f.write(code)
except Exception:
    pass
"

# Atualizar atalhos de apps já instalados
python3 -c "
import glob, os, re
system_apps = [
    'com.android.calculator2', 'com.android.camera2', 'com.android.contacts',
    'com.android.deskclock', 'com.android.documentsui', 'com.android.email',
    'com.android.gallery3d', 'com.android.inputmethod.latin', 'com.android.settings',
    'com.android.vending', 'com.aurora.store', 'com.google.android.gms',
    'com.google.android.apps.messaging', 'com.google.android.contacts',
    'org.lineageos.aperture', 'org.lineageos.eleven',
    'org.lineageos.etar', 'org.lineageos.jelly', 'org.lineageos.recorder'
]
for p in glob.glob(os.path.expanduser('~/.local/share/applications/waydroid.*.desktop')):
    pkg = os.path.basename(p).replace('waydroid.', '').replace('.desktop', '')
    if pkg in system_apps:
        continue
    with open(p, 'r') as f:
        content = f.read()
    if 'Desktop Action uninstall' not in content:
        m = re.search(r'^Name=(.*)$', content, re.M)
        name = m.group(1).strip() if m else pkg
        content = content.replace('Actions=app-settings;', 'Actions=uninstall;app-settings;')
        content += f'''
[Desktop Action uninstall]
Name=Desinstalar aplicativo
Name[pt_BR]=Desinstalar aplicativo
Name[en]=Uninstall application
Exec=/usr/local/bin/waydroid-uninstall {pkg} \"{name}\"
Icon=edit-delete
'''
        with open(p, 'w') as f:
            f.write(content)
"

# 8.5 Atalhos úteis na Área de Trabalho
DESKTOP_DIR="$HOME/Área de trabalho"
[ ! -d "$DESKTOP_DIR" ] && DESKTOP_DIR="$HOME/Desktop"

if [ -d "$DESKTOP_DIR" ]; then
    cat << 'EOF' > "$DESKTOP_DIR/Iniciar-Android.desktop"
[Desktop Entry]
Encoding=UTF-8
Version=1.0
Type=Application
Terminal=false
Exec=waydroid show-full-ui
Name=Iniciar Android (Waydroid)
Comment=Inicia a tela do Android com Google Play Store
Icon=waydroid
Categories=System;
EOF

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
AVISO IMPORTANTE: REINICIALIZAÇÃO DO SISTEMA
--------------------------------------------------------------------
Para que o Android inicialize e não feche sozinho, o sistema precisa
do parâmetro de kernel "psi=1". Se foi feita a configuração recente
no GRUB, REINICIE o computador uma vez antes de abrir o Android.

--------------------------------------------------------------------
PASSO 1: ENTRAR NA SESSÃO WAYLAND (OBRIGATÓRIO)
--------------------------------------------------------------------
O Waydroid precisa da tecnologia Wayland para funcionar com aceleração
gráfica da sua placa de vídeo.

1. Vá no Menu Iniciar do Regata OS.
2. Clique em "Encerrar Sessão" (ou "Sair").
3. Na tela de login (onde digita sua senha):
   -> Olhe no CANTO INFERIOR ESQUERDO da tela.
   -> Clique no seletor de sessão e confirme se está em:
      "Plasma (Wayland)"
4. Digite sua senha e entre no sistema.

--------------------------------------------------------------------
PASSO 2: ABRIR O ANDROID
--------------------------------------------------------------------
1. Dê 2 cliques no atalho "Iniciar Android (Waydroid)" na Área de Trabalho
   (ou no Menu Iniciar clicando em "Waydroid").
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
• DESINSTALAR JOGOS/APPS (100% GRÁFICO):
  Basta clicar com o botão direito em qualquer app do Android no Menu
  Iniciar do Regata OS e escolher "Desinstalar aplicativo".

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

    chmod +x "$DESKTOP_DIR/Iniciar-Android.desktop" "$DESKTOP_DIR/Certificar-PlayStore.desktop" "$DESKTOP_DIR/Parar-Android.desktop" 2>/dev/null || true
fi

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BOLD}${GREEN}        INSTALAÇÃO E OTIMIZAÇÕES CONCLUÍDAS COM SUCESSO!         ${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""
echo -e "${BOLD}Otimizações ativas:${NC}"
echo -e "✔️ Correção de Pressure Stall Information (psi=1) no kernel"
echo -e "✔️ Perfil homologado de Google Pixel 6 Pro ativo (Play Store oficial)"
echo -e "✔️ Suporte a jogos com Anti-Tamper/PairIP (Magisk Delta + Play Integrity Fix + LSPosed)"
echo -e "✔️ Loja complementar Aurora Store pré-instalada (acesso FOSS à Play Store)"
echo -e "✔️ Redução de latência do mouse ativa"
echo -e "✔️ Atalho 'Iniciar Android (Waydroid)' criado na Área de Trabalho"
echo -e "✔️ Clique direito em arquivos .APK para instalar direto"
echo -e "✔️ Desinstalação gráfica com 1 clique (botão direito no Menu Iniciar)"
echo -e "✔️ Atalho na Área de Trabalho para 'Parar Android' e liberar RAM"
echo -e "✔️ Atalho para 'Certificar Google Play' com cópia automática do ID"
echo ""

if [ "$NEED_REBOOT" -eq 1 ]; then
    echo -e "${BOLD}${RED}⚠️  ATENÇÃO: REINICIALIZAÇÃO NECESSÁRIA!${NC}"
    echo -e "O parâmetro de kernel ${BOLD}psi=1${NC} foi configurado no GRUB."
    echo -e "${BOLD}Por favor, REINICIE o computador uma vez antes de abrir o Android.${NC}"
    echo -e "Após reiniciar, entre na sessão 'Plasma (Wayland)' e abra o Android!"
else
    echo -e "${BOLD}Como abrir o Android:${NC}"
    echo -e "1. Confirme que está na sessão ${BOLD}${YELLOW}'Plasma (Wayland)'${NC}."
    echo -e "2. Dê 2 cliques em ${GREEN}Iniciar Android${NC} na Área de Trabalho ou no menu iniciar."
fi
echo ""
read -p "Pressione [Enter] para fechar..."
