# 🤖 Android no Regata OS (Instalador Automatizado)

Instalador automatizado do **Android (Waydroid)** com **Google Play Store (GAPPS)**, **tradutor ARM (libndk)** e **otimizações de desktop** pré-configurados para o **Regata OS**.

Ideal para rodar jogos e aplicativos de Android diretamente no Regata OS com desempenho nativo e aceleração gráfica por hardware.

---

## 🚀 Instalação Rápida (Comando Único)

Em qualquer instalação limpa ou recém-formatada do Regata OS, abra o terminal e execute:

```bash
curl -sSL https://raw.githubusercontent.com/marquimRcc/android-regataos-linux/main/install.sh | bash
```

---

## ⚡ O que o script faz e otimiza automaticamente:

1. **Dependências do sistema:** Instala `lxc`, `python313-gobject`, `python313-pyclipper`, `curl`, `tar`, `xclip`.
2. **Correção de pacotes:** Instala o Waydroid e atualiza a biblioteca `libgbinder1` para compatibilidade total com o Python 3.13.
3. **Android Oficial (GAPPS):** Baixa e inicializa a imagem LineageOS com **Google Play Store e Google Play Services**.
4. **Suporte a Jogos ARM (libndk):** Ativa tradução ARM para suporte a 99% dos jogos e apps mobile (Free Fire, Roblox, Brawl Stars, etc.).
5. **Otimizações de Latência:** Reduz o atraso do cursor do mouse em jogos no Wayland (`persist.waydroid.cursor_on_subsurface`).
6. **Integração com Dolphin (Gerenciador de Arquivos):** Permite clicar com o botão direito em qualquer arquivo `.apk` e escolher **"Instalar no Android (Waydroid)"**.
7. **Atalhos Automáticos na Área de Trabalho:**
   - **`Certificar Google Play`**: Obtém seu ID, copia para a área de transferência e abre o site de liberação do Google.
   - **`Parar Android (Liberar RAM)`**: Encerra o contêiner e libera toda a memória RAM quando você parar de jogar/usar.

---

## 🖥️ Como abrir o Android após a instalação

O Waydroid requer uma sessão **Wayland** para renderização acelerada:

1. Salve seus trabalhos e faça **Logout (Encerrar Sessão)** no Regata OS.
2. Na tela de login (SDDM), clique no seletor de sessão (canto inferior esquerdo) e escolha **Plasma (Wayland)**.
3. Digite sua senha e faça login.
4. Abra o menu de aplicativos e clique em **Waydroid** (ou digite `waydroid show-full-ui` no terminal).

---

## 🔑 Certificação da Google Play Store

Ao abrir a Play Store pela primeira vez, se aparecer a mensagem *"Dispositivo não certificado"*:
- Basta dar dois cliques no atalho **`Certificar Google Play`** na sua Área de Trabalho (ele copia o código e abre o link do Google automaticamente).

---

## 📄 Licença
Distribuído sob a licença [MIT](LICENSE).
