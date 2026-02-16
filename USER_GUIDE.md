# User Guide - SmartWrite Installer

Welcome to the **SmartWrite Installer**! This tool helps you easily install and manage SmartWrite plugins for Obsidian.

## 🚀 Getting Started

### Prerequisites
- **macOS / Linux / Windows (WSL)**
- **Bash** (Terminal)
- **Git** (Installed and configured)
- **Curl**
- **JQ** (JSON Processor) - *The script will warn you if missing.*

### Installation
1.  Clone this repository:
    ```bash
    git clone https://github.com/zandercpzed/smartwrite-installer.git
    cd smartwrite-installer
    ```
2.  Make the script executable:
    ```bash
    chmod +x install.sh
    ```

## 🛠 Usage

To start the installer, simply run:

```bash
./install.sh
```

### The Interactive Flow
1.  **Fetching Plugins**: The script downloads the latest list of plugins from `plugins.json`.
2.  **Vault Detection**: It tries to find your Obsidian Vaults automatically by reading your Obsidian config.
    *   If found, select the number corresponding to your Vault.
    *   If not found, you can paste the full path to your Vault manually.
3.  **Plugin Selection**: You will see a list of available plugins.
    *   Type the numbers of the plugins you want to install, separated by spaces (e.g., `0 2`).
4.  **Installation**: The script clones the selected plugins into your Vault's `.obsidian/plugins/` folder.

## 🔄 Updating Plugins
To update your installed plugins, simply run the installer again and select the same plugins. The script detects existing installations and runs `git pull` to update them.

## ❓ FAQ

**Q: Where are the plugins installed?**
A: They go into `<YourVaultPath>/.obsidian/plugins/<PluginID>`.

**Q: I don't see the plugins in Obsidian.**
A: After installation, you must **Restart Obsidian** or go to `Settings > Community Plugins` and click "Reload plugins". Then, enable them in the list.
