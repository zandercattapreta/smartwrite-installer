# Perguntas Frequentes (FAQ)

### 1. O que este instalador faz?
Ele gerencia a instalação e atualização dos plugins SmartWrite para o Obsidian, detectando automaticamente seus cofres (vaults).

### 2. Quais são as dependências de cada sistema?
- **macOS:** Git e macOS 14.0+.
- **Windows:** Git (essencial) e `jq` (recomendado para melhor performance).
- **Linux:** `git`, `curl` e `jq` (essenciais).

### 3. Onde encontro os plugins instalados?
Os plugins são colocados na pasta `.obsidian/plugins` dentro de cada cofre que você selecionou durante a execução.

### 4. Erros Comuns:
- **macOS: "Desenvolvedor não identificado"**
  - Vá em *Ajustes do Sistema > Privacidade e Segurança* e clique em "Abrir Mesmo Assim".
- **Windows: Erro de execução de script (Policy)**
  - O Windows pode bloquear o `install.ps1`. No PowerShell (Admin), execute:
    ```powershell
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
    ```
- **Linux: Erro "jq not found"**
  - Instale o `jq` via gerenciador de pacotes: `sudo apt install jq` ou similar.

### 5. Como atualizar plugins já instalados?
Basta rodar o instalador novamente. Ele fará um `git pull` nos plugins existentes para garantir que você tenha a versão mais recente.

---
© 2026 Z•Edições.
