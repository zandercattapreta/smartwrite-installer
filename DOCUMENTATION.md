# Documentação Técnica e Funcional: SmartWrite Installer

## 1. Visão Geral (Overview)

O **SmartWrite Installer** é um utilitário bash (`install.sh`) projetado para automatizar a distribuição e "side-loading" dos plugins do ecossistema SmartWrite para o Obsidian. Como estes plugins são exclusivos (ou estão em fase de homologação) e podem não estar listados na Community Plugins nativa, este script resolve a dor de instalação manual.

## 2. Arquitetura (Technical Design)

O projeto é mantido propositalmente minimalista. Não há dependências complexas (sem npm ou node_modules), garantindo que ele rode nativamente em terminais Unix/macOS.

### 2.1 Dependências de Sistema:
Para funcionar, o ambiente do usuário requer:
* **`bash`**: O shell executor padrão.
* **`git`**: Usado no core da ferramenta para instalar via `git clone` e atualizar via `git pull`.
* **`curl`**: Responsável pela requisição HTTP (`GET`) ao catálogo hospedado remotamente.
* **`jq`**: Ferramenta estritamente necessária para parsear JSON em linha de comando (tanto o catálogo remoto quanto as configurações do sistema de arquivos).

### 2.2 Estrutura de Arquivos:
* `install.sh`: O script orquestrador.
* `plugins.json`: O arquivo de catálogo que atua como índice mestre (source of truth) de quais plugins são compatíveis e onde encontrá-los.

## 3. Fluxo Funcional (User Flow)

Quando o usuário executa o `./install.sh`, as seguintes rotinas são disparadas sequencialmente:

### Passo 1: Fetch do Catálogo de Plugins
* O script tenta acessar a URL oficial em `https://raw.githubusercontent.com/zandercpzed/smartwrite-installer/main/plugins.json`.
* O script possui um modo de "dogfooding": se o `plugins.json` for encontrado localmente, ele ignora o `curl` remoto e processa o arquivo local via comando `cat`. Isso é muito útil para desenvolvimento (o que permite testar descrições e repositórios não-publicados).

### Passo 2: Descoberta de Cofres (Vault Auto-Discovery)
* Em sistemas **macOS**, o Obsidian salva os metadados dos cofres abertos recentemente no arquivo `~/Library/Application Support/obsidian/obsidian.json`.
* O instalador utiliza o `jq` para ler a propriedade `.vaults`, iterando e extraindo a chave `.path` para listar os caminhos reais na máquina do usuário.
* O usuário seleciona o número correspondente ao cofre destino. Caso nenhum cofre seja descoberto (ou o usuário esteja no Windows/Linux onde o caminho do config muda), o script entra no "Modo Manual", solicitando o caminho absoluto do diretório do vault na unha.

### Passo 3: Menu Interativo de Seleção
* O conteúdo de `plugins.json` é formatado na tela com `jq` e `nl`.
* É apresentado um menu de escolhas onde o usuário pode digitar as "IDs numéricas" separadas por espaço (Ex: `0 1 2`).

### Passo 4: Motor de Instalação/Update
Para cada ID selecionada, o script analisa o destino: `[TARGET_VAULT]/.obsidian/plugins/[plugin_id]/`:
* **Se o diretório já existir**: A ferramenta faz um `cd` para a pasta e roda um `git pull` seguro, garantindo que o plugin receba as atualizações mais recentes do código-fonte.
* **Se o diretório não existir**: A ferramenta usa `git clone [repo_url]` clonando o repositório na pasta.

## 4. O Manifesto `plugins.json`

```json
[
  {
    "name": "SmartWrite Companion",
    "description": "Intelligent writing assistant com análise e persona feedback.",
    "repo_url": "https://github.com/zandercpzed/smartwrite-companion",
    "id": "smartwrite-companion"
  }
]
```
* **`id`**: Atributo vital. Ele obriga o diretório clonado a ter este exato nome, pois o Obsidian só ativa plugins cujo nome da pasta seja idêntico à chave `id` interna do `manifest.json`.

## 5. Limitações Conhecidas
1. **Compilação Ausente:** Atualmente, a instalação é um mero download dos fontes do repositório. O script presume que a branch `main` clonada possui uma pasta `dist/` ou o arquivo pré-compilado `main.js`. Se o código remoto não estiver "buildado", a ativação do plugin no Obsidian irá falhar.
2. **Pathing de Auto-Discovery:** O pathing `$HOME/Library/Application Support/obsidian/obsidian.json` está chumbado no script e é focado especificamente na arquitetura do Apple macOS.
