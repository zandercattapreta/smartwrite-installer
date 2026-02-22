#!/bin/bash

# Configuration
REPO_OWNER="zandercpzed"
OBSIDIAN_CONFIG="$HOME/Library/Application Support/obsidian/obsidian.json"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== SmartWrite Installer ===${NC}"

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed.${NC}"
    exit 1
fi
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed.${NC}"
    exit 1
fi

# 1. Discover Plugins Dynamically from GitHub
echo -e "\n${BLUE}[1/4] Discovering SmartWrite plugins from GitHub...${NC}"

# Get list of repo names matching the pattern
REPOS=$(curl -s "https://api.github.com/users/$REPO_OWNER/repos?per_page=100" | jq -r '.[].name | select(test("^smartwrite(r)?-.*")) | select(. != "smartwrite-installer")')

if [ -z "$REPOS" ]; then
    echo -e "${RED}Failed to discover plugins from GitHub. Check your connection or API limits.${NC}"
    exit 1
fi

# Build JSON array dynamically
PLUGINS_JSON="[]"

for repo in $REPOS; do
    echo "  -> Found repository: $repo"
    # Fetch manifest.json to get accurate plugin metadata
    MANIFEST=$(curl -s "https://raw.githubusercontent.com/$REPO_OWNER/$repo/main/manifest.json")
    if echo "$MANIFEST" | jq -e . >/dev/null 2>&1; then
        REPO_URL="https://github.com/$REPO_OWNER/$repo.git"
        # Create a valid JSON object matching our expected format
        PLUGIN_OBJ=$(echo "$MANIFEST" | jq --arg url "$REPO_URL" '{id: .id, name: .name, description: .description, repo_url: $url}')
        PLUGINS_JSON=$(echo "$PLUGINS_JSON" | jq --argjson plugin "$PLUGIN_OBJ" '. + [$plugin]')
    else
        echo "     (Skipping: No valid manifest.json found in the main branch)"
    fi
done

if [ "$PLUGINS_JSON" == "[]" ]; then
    echo -e "${RED}No valid SmartWrite plugins found.${NC}"
    exit 1
fi

# 2. Detect Vaults
echo -e "\n${BLUE}[2/4] Detecting Obsidian Vaults...${NC}"
VAULTS=()
if [ -f "$OBSIDIAN_CONFIG" ]; then
    # Parse vaults from obsidian.json (keys are random IDs, values have 'path')
    while IFS= read -r path; do
        if [ -d "$path" ]; then
            VAULTS+=("$path")
        fi
    done < <(jq -r '.vaults | to_entries[].value.path' "$OBSIDIAN_CONFIG")
fi

if [ ${#VAULTS[@]} -eq 0 ]; then
    echo "No Obsidian configuration found or no vaults detected."
    read -p "Enter full path to your Obsidian Vault: " MANUAL_PATH
    if [ -d "$MANUAL_PATH" ]; then
        VAULTS+=("$MANUAL_PATH")
    else
        echo -e "${RED}Invalid directory.${NC}"
        exit 1
    fi
fi

# Select Vault
echo "Found ${#VAULTS[@]} vault(s):"
for i in "${!VAULTS[@]}"; do
    echo "[$i] ${VAULTS[$i]}"
done

read -p "Select Vault to install into (0-$((${#VAULTS[@]}-1))): " VAULT_IDX
TARGET_VAULT="${VAULTS[$VAULT_IDX]}"

if [ -z "$TARGET_VAULT" ]; then
    echo -e "${RED}Invalid selection.${NC}"
    exit 1
fi

echo -e "Selected Vault: ${GREEN}$TARGET_VAULT${NC}"

# 3. Select Plugins
echo -e "\n${BLUE}[3/4] Available Plugins:${NC}"
echo "$PLUGINS_JSON" | jq -r '.[] | "\(.id): \(.name) - \(.description)"' | nl -v 0 -w 2 -s ". "

echo "Enter the numbers of plugins to install (space separated, e.g., '0 2'):"
read -r -a PLUGIN_SELECTIONS

# 4. Install Plugins
echo -e "\n${BLUE}[4/4] Installing...${NC}"
PLUGIN_DIR="$TARGET_VAULT/.obsidian/plugins"
mkdir -p "$PLUGIN_DIR"

for idx in "${PLUGIN_SELECTIONS[@]}"; do
    # Get plugin details using jq
    PLUGIN_DATA=$(echo "$PLUGINS_JSON" | jq -r ".[$idx]")
    
    if [ "$PLUGIN_DATA" == "null" ] || [ -z "$PLUGIN_DATA" ]; then
        echo -e "${RED}Skipping invalid selection: $idx${NC}"
        continue
    fi
    
    ID=$(echo "$PLUGIN_DATA" | jq -r '.id')
    NAME=$(echo "$PLUGIN_DATA" | jq -r '.name')
    URL=$(echo "$PLUGIN_DATA" | jq -r '.repo_url')
    
    TARGET_DIR="$PLUGIN_DIR/$ID"
    
    echo -e "Installing ${GREEN}$NAME${NC}..."
    
    if [ -d "$TARGET_DIR" ]; then
        echo "  Updating existing installation..."
        cd "$TARGET_DIR" && git pull
    else
        echo "  Cloning repository..."
        git clone "$URL" "$TARGET_DIR"
    fi
    
    echo "  Done."
done

echo -e "\n${GREEN}Installation Complete!${NC}"
echo "Please restart Obsidian or reload plugins to see changes."
