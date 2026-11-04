# 🤖 Android no Regata OS (Instalador Automatizado)

Instalador automatizado do **Android (Waydroid)** com **Google Play Store (GAPPS)** e **tradutor ARM (libndk)** pré-configurados para o **Regata OS**.

Ideal para rodar jogos e aplicativos de Android diretamente no Regata OS com desempenho nativo e aceleração gráfica por hardware.

---

## 🚀 Instalação Rápida (Comando Único)

Em qualquer instalação limpa ou recém-formatada do Regata OS, abra o terminal e execute:

```bash
curl -sSL https://raw.githubusercontent.com/marquimRcc/android-regataos-linux/main/install.sh | bash
```

Ou, se preferir clonar o repositório:

```bash
git clone https://github.com/marquimRcc/android-regataos-linux.git
cd android-regataos-linux
chmod +x install.sh
./install.sh
```

---

## ⚙️ O que o script faz automaticamente:

1. **Instalação das dependências base:** `lxc`, `python313-gobject`, `python313-pyclipper`, `curl`, `tar`.
2. **Resolução de dependências do Waydroid:** Instala o pacote oficial contornando incompatibilidades de versão dos repositórios.
3. **Auto-atualização da `libgbinder1`:** Aplica a versão compatível com Python 3.13 e runtime binder.
4. **Download do Android GAPPS:** Inicializa a imagem oficial do LineageOS com **Google Play Store** e **Google Play Services**.
5. **Suporte a Jogos e Apps ARM (libndk):** Configura a camada de tradução ARM para compatibilidade com a esmagadora maioria dos apps e jogos da Play Store.
6. **Ativação dos Serviços:** Inicia e habilita o serviço `waydroid-container` no systemd.

---

## 🖥️ Como abrir o Android após a instalação

O Waydroid requer uma sessão **Wayland** para renderização acelerada:

1. Salve seus trabalhos e faça **Logout (Encerrar Sessão)** no Regata OS.
2. Na tela de login (SDDM), clique no seletor de sessão (canto inferior esquerdo) e escolha **Plasma (Wayland)**.
3. Digite sua senha e faça login.
4. Abra o menu de aplicativos e clique em **Waydroid** (ou digite `waydroid show-full-ui` no terminal).

---

## 🔑 Certificação da Google Play Store (Dispositivo Não Certificado)

Ao abrir a Play Store pela primeira vez, se aparecer a mensagem *"Dispositivo não certificado pelo Play Protect"*:

1. No terminal, execute:
   ```bash
   cd ~/waydroid_script && ./venv/bin/python3 main.py certified
   ```
2. Copie o ID numérico exibido na tela.
3. Acesse a página oficial: [google.com/android/uncertified](https://www.google.com/android/uncertified/)
4. Faça login com sua conta Google e cole o ID para registrar seu aparelho virtual.

---

## 📄 Licença
Distribuído sob a licença [MIT](LICENSE).
