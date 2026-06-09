# SmartWrite Installer

O **SmartWrite Installer** é o gerenciador oficial para a suíte de plugins SmartWrite para Obsidian, desenvolvido pela **Z•Edições**. Ele detecta automaticamente seus cofres (vaults) e permite instalar ou atualizar os plugins do ecossistema de forma centralizada.

---

## 🚀 Instalação por Plataforma

### 🍎 macOS (Recomendado)
1. Baixe o arquivo **`SmartWriteInstaller.dmg`**.
2. Arraste o aplicativo para a pasta **Applications**.
3. Abra o aplicativo (pode ser necessário autorizar em *Ajustes do Sistema > Privacidade e Segurança*).

### 🪟 Windows (PowerShell)
1. Certifique-se de ter o [Git](https://git-scm.com/download/win) instalado.
2. Baixe o arquivo **`install.ps1`**.
3. Clique com o botão direito no arquivo e selecione **"Executar com o PowerShell"**.
4. Siga as instruções no terminal.

### 🐧 Linux (Debian/Ubuntu/Outros)
1. Certifique-se de ter `git`, `curl` e `jq` instalados (`sudo apt install git curl jq`).
2. Baixe o arquivo **`install.sh`**.
3. No terminal, execute:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

---

## 🛠️ Dependências Necessárias

| Plataforma | Requisito Principal | Ferramentas Extras |
| :--- | :--- | :--- |
| **macOS** | macOS 14.0+ | Git (embutido ou via Homebrew) |
| **Windows** | PowerShell 5.1+ | **Git** (obrigatório), **jq** (opcional para melhor detecção) |
| **Linux** | Bash | **Git**, **curl**, **jq** (obrigatórios) |

---

## 📦 Plugins Incluídos no Ecossistema
- **SmartWrite Companion:** Assistente de escrita inteligente.
- **SmartWriter Analyzer:** Analisador de qualidade de manuscritos.
- **SmartWrite Publisher:** Automação para Substack.

## 📄 Licença
Licenciado sob a [MIT License](LICENSE.md).
© 2026 Z•Edições.
