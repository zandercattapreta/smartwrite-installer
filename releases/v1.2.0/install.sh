#!/bin/bash
# ==============================================================================
# SCRIPT: install.sh
# DESCRIÇÃO: Instalador dinâmico da suíte SmartWrite para o Obsidian.
#            Descobre plugins via GitHub API, detecta vaults automaticamente
#            e instala/atualiza via git clone/pull com build automático npm.
# CHAMADO POR: Terminal do usuário — execução direta: ./install.sh
#              Flags: --build / -b  → força recompilação mesmo se main.js existir
# TRAZ (CHAMA/IMPORTA): bash, curl (GitHub API), jq (parsing JSON),
#                        git (clone/pull), npm (install + build de plugins)
# CONTRATO (RESPOSTA ESPERADA): Instala ou atualiza os plugins SmartWrite
#            selecionados pelo usuário nos vaults do Obsidian indicados.
#            Saída: mensagens de progresso no terminal. Exit 0 = sucesso.
# ==============================================================================

# Configuration
REPO_OWNER="zandercpzed"
FORCE_BUILD=false

# Check for flags
for arg in "$@"; do
    if [ "$arg" == "--build" ] || [ "$arg" == "-b" ]; then
        FORCE_BUILD=true
    fi
done

# Detect OS and set Obsidian Config Path
if [[ "$OSTYPE" == "darwin"* ]]; then
    OBSIDIAN_CONFIG="$HOME/Library/Application Support/obsidian/obsidian.json"
else
    OBSIDIAN_CONFIG="$HOME/.config/obsidian/obsidian.json"
fi

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== SmartWrite Installer v2.1 ===${NC}"

# Check dependencies
for cmd in jq curl git npm; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: $cmd is not installed.${NC}"
        exit 1
    fi
done

# 1. Discover Plugins Dynamically from GitHub
echo -e "\n${BLUE}[1/4] Discovering SmartWrite plugins from GitHub...${NC}"

REPOS=$(curl -s "https://api.github.com/users/$REPO_OWNER/repos?per_page=100" | jq -r '.[].name | select(test("^smartwrite(r)?-.*")) | select(. != "smartwrite-installer")')

if [ -z "$REPOS" ]; then
    echo -e "${RED}Failed to discover plugins. Check connection.${NC}"
    exit 1
fi

PLUGINS_JSON="[]"
for repo in $REPOS; do
    echo "  -> Found repository: $repo"
    MANIFEST=""
    for branch in "main" "master"; do
        MANIFEST=$(curl -s "https://raw.githubusercontent.com/$REPO_OWNER/$repo/$branch/manifest.json")
        if echo "$MANIFEST" | jq -e . >/dev/null 2>&1; then
            echo "     (Manifest found in '$branch')"
            break
        else
            MANIFEST=""
        fi
    done

    if [ -n "$MANIFEST" ]; then
        REPO_URL="https://github.com/$REPO_OWNER/$repo.git"
        PLUGIN_OBJ=$(echo "$MANIFEST" | jq --arg url "$REPO_URL" '{id: .id, name: .name, description: .description, repo_url: $url}')
        PLUGINS_JSON=$(echo "$PLUGINS_JSON" | jq --argjson plugin "$PLUGIN_OBJ" '. + [$plugin]')
    fi
done

# 2. Detect Vaults
echo -e "\n${BLUE}[2/4] Detecting Obsidian Vaults...${NC}"
VAULTS=()
if [ -f "$OBSIDIAN_CONFIG" ]; then
    while IFS= read -r path; do
        [ -d "$path" ] && VAULTS+=("$path")
    done < <(jq -r '.vaults | to_entries[].value.path' "$OBSIDIAN_CONFIG")
fi

if [ ${#VAULTS[@]} -eq 0 ]; then
    read -p "Enter full path to your Obsidian Vault: " MANUAL_PATH
    [ -d "$MANUAL_PATH" ] && VAULTS+=("$MANUAL_PATH") || { echo -e "${RED}Invalid path.${NC}"; exit 1; }
fi

for i in "${!VAULTS[@]}"; do echo "[$i] ${VAULTS[$i]}"; done
echo ""
read -p "Enter vault numbers (e.g., '0'): " -a VAULT_SELECTIONS

SELECTED_VAULTS=()
for vidx in "${VAULT_SELECTIONS[@]}"; do
    [ -n "${VAULTS[$vidx]}" ] && SELECTED_VAULTS+=("${VAULTS[$vidx]}")
done

# 3. Select Plugins
echo -e "\n${BLUE}[3/4] Available Plugins:${NC}"
echo "$PLUGINS_JSON" | jq -r '.[] | "\(.id): \(.name)"' | nl -v 0 -w 2 -s ". "
echo ""
read -p "Enter plugin numbers (e.g., '0 1'): " -a PLUGIN_SELECTIONS

SELECTED_PLUGINS="[]"
for idx in "${PLUGIN_SELECTIONS[@]}"; do
    PLUGIN_DATA=$(echo "$PLUGINS_JSON" | jq -r ".[$idx]")
    if [ "$PLUGIN_DATA" != "null" ]; then
        SELECTED_PLUGINS=$(echo "$SELECTED_PLUGINS" | jq --argjson p "$PLUGIN_DATA" '. + [$p]')
    fi
done

# 4. Installation & Build Logic
# ------------------------------------------------------------------------------
# check_and_build()
# Verifica se um plugin precisa ser compilado e executa npm install + npm run build.
#
# Parâmetros:
#   $1 — DIR:  Caminho absoluto do diretório do plugin (onde package.json está)
#   $2 — NAME: Nome do plugin (apenas para exibição nos logs)
#
# Comportamento:
#   - Se main.js existir e FORCE_BUILD=false → retorna 0 sem fazer nada
#   - Se package.json não existir → retorna 0 sem fazer nada
#   - Caso contrário: executa npm install e npm run build (se script "build" existir)
#   - Verifica se main.js foi gerado após o build como confirmação
#
# Retorno: 0 (sucesso) | 1 (falha em npm install, npm build ou main.js ausente)
# ------------------------------------------------------------------------------
check_and_build() {
    local DIR="$1"
    local NAME="$2"
    local CURRENT_DIR=$(pwd)

    cd "$DIR" || return 1
    
    if [ -f "main.js" ] && [ "$FORCE_BUILD" = false ]; then
        cd "$CURRENT_DIR" && return 0
    fi

    echo -e "    ${BLUE}Building $NAME...${NC}"
    
    npm install --silent
    if [ $? -ne 0 ]; then
        echo -e "    ${RED}✗ npm install failed for $NAME${NC}"
        cd "$CURRENT_DIR" && return 1
    fi

    if grep -q '"build":' package.json; then
        npm run build --silent
        if [ $? -ne 0 ]; then
            echo -e "    ${RED}✗ npm run build failed for $NAME${NC}"
            cd "$CURRENT_DIR" && return 1
        fi
    fi

    if [ -f "main.js" ]; then
        echo -e "    ${GREEN}✓ Build successful.${NC}"
        cd "$CURRENT_DIR" && return 0
    else
        echo -e "    ${RED}✗ Build finished but main.js missing.${NC}"
        cd "$CURRENT_DIR" && return 1
    fi
}

echo -e "\n${BLUE}[4/4] Installing...${NC}"
for TARGET_VAULT in "${SELECTED_VAULTS[@]}"; do
    PLUGIN_DIR="$TARGET_VAULT/.obsidian/plugins"
    mkdir -p "$PLUGIN_DIR"
    
    echo "$SELECTED_PLUGINS" | jq -c '.[]' | while read -r plugin; do
        ID=$(echo "$plugin" | jq -r '.id')
        NAME=$(echo "$plugin" | jq -r '.name')
        URL=$(echo "$plugin" | jq -r '.repo_url')
        TARGET_PATH="$PLUGIN_DIR/$ID"

        echo -e "  -> ${GREEN}$NAME${NC} ($ID)"
        if [ -d "$TARGET_PATH" ]; then
            (cd "$TARGET_PATH" && git pull --quiet)
        else
            git clone --quiet "$URL" "$TARGET_PATH"
        fi

        if ! check_and_build "$TARGET_PATH" "$NAME"; then
            echo -e "  ${RED}!!! Installation of $NAME failed during build step !!!${NC}"
        else
            echo -e "  ${GREEN}✓ Done.${NC}"
        fi
    done
done

echo -e "\n${GREEN}Process Complete.${NC} Please check Obsidian."
