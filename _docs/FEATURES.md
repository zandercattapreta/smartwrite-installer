# Features & Capabilities

## ✅ core Features

### 1. Centralized Plugin Index
- **Dynamic List**: The installer fetches the list of plugins from a remote JSON file. This means we can add new plugins to the ecosystem without updating the installer script used by clients.
- **Metadata**: Each plugin entry contains the name, description, repository URL, and installation ID.

### 2. Intelligent Vault Detection
- **Auto-Discovery**: Automatic parsing of Obsidian's `obsidian.json` configuration file to locate registered Vaults.
- **Cross-Platform Support**: Logic to detect file paths on macOS (standard paths). *Windows/Linux support logic exists but is currently optimized for Unix-like environments.*
- **Manual Fallback**: If no Vaults are found, the user can manually input the path.

### 3. Smart Installation
- **Idempotency**:
    - If a plugin **does not exist**, it performs a `git clone`.
    - If a plugin **already exists**, it performs a `git pull` to update it.
- **Dependency Checks**: The script verifies if necessary tools (`jq`) are installed before running.

## 🚀 Future Roadmap (Planned)
- [ ] **Release Management**: Support for installing specific release versions (tags) instead of just the `main` branch.
- [ ] **Dependency Resolution**: Automatically install dependencies if a plugin requires them.
- [ ] **GUI**: A graphical interface (Electron/Neutralinojs) for easier usage (Attempted previously, currently on hold).
