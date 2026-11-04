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

1. **Correção de Kernel (Pressure Stall Information - `psi=1`):** Adiciona o parâmetro de gerenciamento de processos e memória ao GRUB, evitando que o contêiner Android feche sozinho no boot.
2. **Configuração de Rede e Firewall (`firewalld`):** Libera a interface virtual `waydroid0` na zona confiável (`trusted`) e ativa mascaramento NAT permanente para acesso imediato à internet no Android.
3. **Dependências do sistema:** Instala `lxc`, `python313-gobject`, `python313-pyclipper`, `dnsmasq`, `curl`, `tar`, `xclip`.
4. **Correção de pacotes:** Instala o Waydroid, atualiza `libgbinder1` e fornece o módulo `gbinder` corrigido para o Python 3.13.
5. **Android Oficial (GAPPS):** Baixa e inicializa a imagem LineageOS com **Google Play Store e Google Play Services**.
6. **Perfil de Dispositivo Homologado (Pixel 6 Pro):** Injeta assinatura de hardware oficial de um Google Pixel 6 Pro (`raven`) para autenticação nativa na Google Play Store.
7. **Loja Complementar Aurora Store:** Vem com a loja alternativa de código aberto pré-instalada (permite baixar apps da Play Store com 1 clique, com ou sem conta Google).
8. **Suporte a Jogos ARM (libndk):** Ativa tradução ARM para suporte a 99% dos jogos e apps mobile (Free Fire, Roblox, Brawl Stars, etc.).
9. **Otimizações de Latência:** Reduz o atraso do cursor do mouse em jogos no Wayland (`persist.waydroid.cursor_on_subsurface`).
10. **Integração com Dolphin (Gerenciador de Arquivos):** Permite clicar com o botão direito em qualquer arquivo `.apk` e escolher **"Instalar no Android (Waydroid)"**.
11. **Atalhos Automáticos na Área de Trabalho:**
   - **`Iniciar Android (Waydroid)`**: Atalho direto para iniciar o sistema Android.
   - **`Certificar Google Play`**: Obtém seu ID, copia para a área de transferência e abre o site de liberação do Google (se necessário).
   - **`Parar Android (Liberar RAM)`**: Encerra o contêiner e libera toda a memória RAM quando você parar de jogar/usar.

---

## 🖥️ Como abrir o Android após a instalação

O Waydroid requer uma sessão **Wayland** para renderização acelerada:

1. Se for a primeira instalação e o script configurou o `psi=1`, **reinicie o computador uma vez**.
2. Na tela de login (SDDM), verifique no seletor de sessão (canto inferior esquerdo) se está em **Plasma (Wayland)**.
3. Digite sua senha e faça login.
4. Dê 2 cliques no atalho **`Iniciar Android (Waydroid)`** na Área de Trabalho (ou abra pelo menu de aplicativos).

---

## 🔑 Certificação da Google Play Store

Ao abrir a Play Store pela primeira vez, se aparecer a mensagem *"Dispositivo não certificado"*:
- Basta dar dois cliques no atalho **`Certificar Google Play`** na sua Área de Trabalho (ele copia o código e abre o link do Google automaticamente).

---

## 📄 Licença
Distribuído sob a licença [MIT](LICENSE).
