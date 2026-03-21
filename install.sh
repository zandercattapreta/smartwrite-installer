#!/bin/bash

# Configuration
REPO_OWNER="zandercpzed"

# Detect OS and set Obsidian Config Path
if [[ "$OSTYPE" == "darwin"* ]]; then
    OBSIDIAN_CONFIG="$HOME/Library/Application Support/obsidian/obsidian.json"
else
    # Default for Linux
    OBSIDIAN_CONFIG="$HOME/.config/obsidian/obsidian.json"
fi

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

echo ""
echo "Enter vault numbers to install into (space separated, e.g., '0 2'):"
read -r -a VAULT_SELECTIONS

# Validate vault selections
SELECTED_VAULTS=()
for vidx in "${VAULT_SELECTIONS[@]}"; do
    if ! [[ "$vidx" =~ ^[0-9]+$ ]] || [ "$vidx" -ge "${#VAULTS[@]}" ]; then
        echo -e "${RED}Skipping invalid vault: $vidx${NC}"
        continue
    fi
    SELECTED_VAULTS+=("${VAULTS[$vidx]}")
done

if [ ${#SELECTED_VAULTS[@]} -eq 0 ]; then
    echo -e "${RED}No valid vaults selected.${NC}"
    exit 1
fi

echo -e "Selected ${GREEN}${#SELECTED_VAULTS[@]}${NC} vault(s)."

# --- Helper: Collect custom GitHub URL (pre-install) ---
CUSTOM_PLUGINS_JSON="[]"

collect_custom_url() {
    while true; do
        echo ""
        read -p "> Enter GitHub repository URL (or 'done' to finish): " CUSTOM_URL
        
        if [ "$CUSTOM_URL" == "done" ] || [ "$CUSTOM_URL" == "d" ]; then
            break
        fi
        
        # Validate URL format
        if [[ ! "$CUSTOM_URL" =~ ^https://github\.com/.+/.+ ]]; then
            echo -e "${RED}  Invalid URL. Expected: https://github.com/user/repo${NC}"
            continue
        fi
        
        # Clean URL (remove trailing .git or /)
        CUSTOM_URL="${CUSTOM_URL%.git}"
        CUSTOM_URL="${CUSTOM_URL%/}"
        
        # Extract owner/repo
        REPO_PATH="${CUSTOM_URL#https://github.com/}"
        OWNER=$(echo "$REPO_PATH" | cut -d'/' -f1)
        REPO=$(echo "$REPO_PATH" | cut -d'/' -f2)
        
        echo -e "  Checking ${GREEN}$OWNER/$REPO${NC}..."
        
        # Try to fetch manifest.json
        MANIFEST=$(curl -s "https://raw.githubusercontent.com/$OWNER/$REPO/main/manifest.json")
        
        if echo "$MANIFEST" | jq -e '.id' > /dev/null 2>&1; then
            ID=$(echo "$MANIFEST" | jq -r '.id')
            NAME=$(echo "$MANIFEST" | jq -r '.name // "'$REPO'"')
            DESC=$(echo "$MANIFEST" | jq -r '.description // "No description"')
            echo -e "  ${GREEN}✓${NC} Found plugin: ${GREEN}$NAME${NC} — $DESC"
        else
            echo -e "  No manifest.json found. Using repo name as ID."
            ID="$REPO"
            NAME="$REPO"
            DESC="Custom plugin"
        fi
        
        # Add to custom plugins list
        PLUGIN_OBJ=$(jq -n --arg id "$ID" --arg name "$NAME" --arg desc "$DESC" --arg url "${CUSTOM_URL}.git" \
            '{id: $id, name: $name, description: $desc, repo_url: $url}')
        CUSTOM_PLUGINS_JSON=$(echo "$CUSTOM_PLUGINS_JSON" | jq --argjson plugin "$PLUGIN_OBJ" '. + [$plugin]')
        
        echo -e "  Added to install list. Enter another URL or type ${GREEN}done${NC}."
    done
}

# 3. Select Plugins
echo -e "\n${BLUE}[3/4] Available Plugins:${NC}"
echo "$PLUGINS_JSON" | jq -r '.[] | "\(.id): \(.name) - \(.description)"' | nl -v 0 -w 2 -s ". "
echo -e " ${BLUE}c. Enter GitHub repository URL${NC}"

echo ""
echo "Enter the numbers of plugins to install (space separated, e.g., '0 2 c'):"
read -r -a PLUGIN_SELECTIONS

# If 'c' was selected, collect URLs now (before installing)
SELECTED_INDEX_PLUGINS="[]"
for idx in "${PLUGIN_SELECTIONS[@]}"; do
    if [ "$idx" == "c" ] || [ "$idx" == "C" ]; then
        collect_custom_url
    else
        # Validate and collect index plugin
        PLUGIN_DATA=$(echo "$PLUGINS_JSON" | jq -r ".[$idx]")
        if [ "$PLUGIN_DATA" != "null" ] && [ -n "$PLUGIN_DATA" ]; then
            SELECTED_INDEX_PLUGINS=$(echo "$SELECTED_INDEX_PLUGINS" | jq --argjson p "$PLUGIN_DATA" '. + [$p]')
        else
            echo -e "${RED}Skipping invalid selection: $idx${NC}"
        fi
    fi
done

# Merge all plugins to install
ALL_PLUGINS=$(echo "$SELECTED_INDEX_PLUGINS" "$CUSTOM_PLUGINS_JSON" | jq -s '.[0] + .[1]')
TOTAL=$(echo "$ALL_PLUGINS" | jq 'length')

if [ "$TOTAL" -eq 0 ]; then
    echo -e "${RED}No plugins selected.${NC}"
    exit 1
fi

# Confirmation summary
echo -e "\n${BLUE}=== Installation Summary ===${NC}"
echo -e "Vaults (${#SELECTED_VAULTS[@]}):"
for v in "${SELECTED_VAULTS[@]}"; do
    echo -e "  • $(basename "$v")"
done
echo -e "Plugins ($TOTAL):"
echo "$ALL_PLUGINS" | jq -r '.[] | "  • \(.name)"'

echo ""
read -p "> Proceed with installation? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Installation cancelled."
    exit 0
fi

# --- Helper: Post-clone build check ---
BUILD_CONFIRMED=""
check_and_build() {
    local DIR="$1"
    local NAME="$2"
    
    # If main.js already exists, plugin is ready
    if [ -f "$DIR/main.js" ]; then
        return 0
    fi
    
    # Check if package.json exists (needs build)
    if [ ! -f "$DIR/package.json" ]; then
        return 0
    fi
    
    echo -e "    ${BLUE}⚠ Plugin '$NAME' needs to be compiled (no main.js found).${NC}"
    
    # Check if npm is available
    if ! command -v npm &> /dev/null; then
        echo -e "    ${RED}✗ npm is not installed. Cannot build this plugin.${NC}"
        echo -e "    ${RED}  Install Node.js (https://nodejs.org) and try again.${NC}"
        return 1
    fi
    
    # Ask user for confirmation (only once per session)
    if [ -z "$BUILD_CONFIRMED" ]; then
        echo -e "    This plugin requires: ${GREEN}npm install${NC} + ${GREEN}npm run build${NC}"
        read -p "    > Build this plugin? (y/n/a=all): " BUILD_ANSWER
        
        if [ "$BUILD_ANSWER" == "a" ] || [ "$BUILD_ANSWER" == "A" ]; then
            BUILD_CONFIRMED="yes"
        elif [ "$BUILD_ANSWER" != "y" ] && [ "$BUILD_ANSWER" != "Y" ]; then
            echo -e "    ${RED}Skipping build. Plugin may not work without main.js.${NC}"
            return 1
        fi
    fi
    
    echo -e "    Running ${GREEN}npm install${NC}..."
    cd "$DIR" && npm install --silent 2>&1 | tail -1
    
    if [ -f "$DIR/package.json" ] && grep -q '"build"' "$DIR/package.json"; then
        echo -e "    Running ${GREEN}npm run build${NC}..."
        npm run build --silent 2>&1 | tail -1
    fi
    
    cd - > /dev/null
    
    if [ -f "$DIR/main.js" ]; then
        echo -e "    ${GREEN}✓ Build successful!${NC}"
    else
        echo -e "    ${RED}✗ Build finished but main.js not found. Plugin may not work.${NC}"
    fi
}

# 4. Install Plugins
echo -e "\n${BLUE}[4/4] Installing...${NC}"

for TARGET_VAULT in "${SELECTED_VAULTS[@]}"; do
    VAULT_NAME=$(basename "$TARGET_VAULT")
    echo -e "\n${BLUE}--- Vault: ${GREEN}$VAULT_NAME${NC} ${BLUE}---${NC}"
    
    PLUGIN_DIR="$TARGET_VAULT/.obsidian/plugins"
    mkdir -p "$PLUGIN_DIR"
    
    for row in $(echo "$ALL_PLUGINS" | jq -r '.[] | @base64'); do
        _jq() { echo "$row" | base64 --decode | jq -r "$1"; }
        
        ID=$(_jq '.id')
        NAME=$(_jq '.name')
        URL=$(_jq '.repo_url')
        
        TARGET_DIR="$PLUGIN_DIR/$ID"
        
        echo -e "  Installing ${GREEN}$NAME${NC}..."
        
        if [ -d "$TARGET_DIR" ]; then
            echo "    Updating existing installation..."
            cd "$TARGET_DIR" && git pull && cd - > /dev/null
        else
            echo "    Cloning repository..."
            git clone "$URL" "$TARGET_DIR"
        fi
        
        # Post-clone: check if build is needed
        check_and_build "$TARGET_DIR" "$NAME"
        
        echo "    Done."
    done
done

echo -e "\n${GREEN}Installation Complete!${NC}"
echo "Please restart Obsidian or reload plugins to see changes."

