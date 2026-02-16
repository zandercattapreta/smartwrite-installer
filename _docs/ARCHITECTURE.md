# Architecture Overview

The **SmartWrite Installer** is a lightweight CLI utility designed to simplify the distribution and installation of the SmartWrite ecosystem plugins for Obsidian.

## 🏗 High-Level Design

The system consists of three main components:
1.  **The Installer (`install.sh`)**: A Bash script that orchestrates the logic.
2.  **The Index (`plugins.json`)**: A remote JSON file acting as the "App Store" catalog.
3.  **Client Environment**: The user's machine with Obsidian and Git.

```mermaid
graph TD
    User[User] -->|Runs| Script[./install.sh]
    Script -->|Fetches| Index[plugins.json (GitHub)]
    Script -->|Reads| Config[Obsidian Config (obsidian.json)]
    Script -->|Clones| Repo[Plugin Repositories]
    Repo -->|Installs to| Vault[Obsidian Vault]
```

## 🧩 Components

### 1. Installer Script (`install.sh`)
- **Dependencies**: `curl`, `jq`, `git`.
- **Logic**:
    - **Fetch**: Retrieves `plugins.json`.
    - **Parsers**: Reads `obsidian.json` to extract Vault paths using `jq`.
    - **Git Operations**: Uses `git clone` for new installs and `git pull` for updates.

### 2. Plugin Index (`plugins.json`)
A static JSON file hosted in this repository.
**Schema:**
```json
[
  {
    "name": "Display Name",
    "description": "Short description",
    "repo_url": "https://github.com/user/repo",
    "id": "plugin-folder-name"
  }
]
```

## 📂 Directory Structure

```
smartwrite-installer/
├── install.sh          # Main executable
├── plugins.json        # Plugin catalog
├── USER_GUIDE.md       # End-user documentation
├── _docs/              # Tecthnical documentation
│   ├── ARCHITECTURE.md
│   └── FEATURES.md
└── README.md           # Repository overview
```

## 🔐 Security
- The script executes `git` commands.
- It only reads the user's Obsidian config file (`obsidian.json`) to convenience.
- No data is sent to external servers (other than fetching the public index).
