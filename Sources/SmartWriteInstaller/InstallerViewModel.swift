import Foundation

@MainActor
class InstallerViewModel: ObservableObject {
    @Published var discoveredPlugins: [Plugin] = []
    @Published var selectedPlugins: Set<String> = []
    
    @Published var availableVaults: [ObsidianVault] = []
    @Published var selectedVaults: Set<UUID> = []
    
    @Published var customRepoURL: String = ""
    @Published var installationStatus: InstallationStatus = .idle
    @Published var installationLog: [String] = []
    
    @Published var currentStep: InstallStep = .selectPlugins
    
    private let repoOwner = "zandercpzed"
    private let obsidianConfigPath = "\(NSHomeDirectory())/Library/Application Support/obsidian/obsidian.json"
    
    enum InstallStep: Int, CaseIterable {
        case selectPlugins = 0
        case selectVaults = 1
        case confirm = 2
        case installing = 3
        
        var title: String {
            switch self {
            case .selectPlugins: return "Select Plugins"
            case .selectVaults: return "Select Vaults"
            case .confirm: return "Confirm Installation"
            case .installing: return "Installing"
            }
        }
        
        var description: String {
            switch self {
            case .selectPlugins: return "Choose which SmartWrite plugins to install"
            case .selectVaults: return "Choose which Obsidian vaults to install into"
            case .confirm: return "Review your selections before installing"
            case .installing: return "Installing plugins to your vaults"
            }
        }
    }
    
    // MARK: - Discovery
    
    func discoverPlugins() async {
        installationStatus = .discovering
        addLog("🔍 Discovering SmartWrite plugins from GitHub...")
        
        do {
            let url = URL(string: "https://api.github.com/users/\(repoOwner)/repos?per_page=100")!
            let (data, _) = try await URLSession.shared.data(from: url)
            
            let repos = try JSONDecoder().decode([GitHubRepo].self, from: data)
            
            // Filter repos matching smartwrite pattern
            let smartWriteRepos = repos.filter { repo in
                repo.name.hasPrefix("smartwrite-") || repo.name.hasPrefix("smartwriter-")
            }.filter { repo in
                repo.name != "smartwrite-installer"
            }
            
            addLog("✓ Found \(smartWriteRepos.count) repositories")
            
            // Fetch manifest for each repo
            var plugins: [Plugin] = []
            
            for repo in smartWriteRepos {
                if let plugin = await fetchPluginManifest(repo: repo) {
                    plugins.append(plugin)
                    addLog("  → \(plugin.name)")
                }
            }
            
            discoveredPlugins = plugins
            installationStatus = .idle
            addLog("✓ Discovery complete! Found \(plugins.count) valid plugins")
            
        } catch {
            installationStatus = .failed("Failed to discover plugins: \(error.localizedDescription)")
            addLog("✗ Error: \(error.localizedDescription)")
        }
    }
    
    private func fetchPluginManifest(repo: GitHubRepo) async -> Plugin? {
        let manifestURL = URL(string: "https://raw.githubusercontent.com/\(repoOwner)/\(repo.name)/main/manifest.json")!
        
        do {
            let (data, _) = try await URLSession.shared.data(from: manifestURL)
            let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)
            
            return Plugin(
                id: manifest.id,
                name: manifest.name,
                description: manifest.description ?? "No description available",
                repoUrl: repo.cloneUrl
            )
        } catch {
            // Skip repos without valid manifest
            return nil
        }
    }
    
    // MARK: - Vault Detection
    
    func detectVaults() {
        addLog("🔍 Detecting Obsidian vaults...")
        
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: obsidianConfigPath) else {
            addLog("⚠ No Obsidian configuration found at default location")
            return
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: obsidianConfigPath))
            let config = try JSONDecoder().decode(ObsidianConfig.self, from: data)
            
            let vaults = config.vaults.values.compactMap { info -> ObsidianVault? in
                let expandedPath = NSString(string: info.path).expandingTildeInPath
                guard fileManager.fileExists(atPath: expandedPath) else { return nil }
                return ObsidianVault(path: expandedPath)
            }
            
            availableVaults = vaults
            addLog("✓ Found \(vaults.count) vault(s)")
            
            for vault in vaults {
                addLog("  → \(vault.name)")
            }
            
        } catch {
            addLog("✗ Error reading Obsidian config: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Manual Vault

    func addManualVault(path: String) {
        let expandedPath = NSString(string: path.trimmingCharacters(in: .whitespaces)).expandingTildeInPath
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: expandedPath) else {
            addLog("⚠ Caminho não encontrado: \(expandedPath)")
            return
        }
        let vault = ObsidianVault(path: expandedPath)
        if !availableVaults.contains(where: { $0.path == expandedPath }) {
            availableVaults.append(vault)
            selectedVaults.insert(vault.id)
            addLog("✓ Vault adicionado manualmente: \(vault.name)")
        } else {
            addLog("⚠ Vault já listado: \(vault.name)")
        }
    }

    // MARK: - Custom Plugin
    
    func addCustomPlugin() async {
        guard !customRepoURL.isEmpty else { return }
        
        addLog("🔍 Checking custom repository: \(customRepoURL)")
        
        // Clean URL
        var cleanURL = customRepoURL
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ".git", with: "")
        
        if cleanURL.hasSuffix("/") {
            cleanURL.removeLast()
        }
        
        // Extract owner/repo
        guard let repoPath = cleanURL.components(separatedBy: "github.com/").last else {
            addLog("✗ Invalid GitHub URL")
            return
        }
        
        let parts = repoPath.split(separator: "/")
        guard parts.count >= 2 else {
            addLog("✗ Invalid repository path")
            return
        }
        
        let owner = String(parts[0])
        let repoName = String(parts[1])
        
        // Try fetching manifest
        let manifestURL = URL(string: "https://raw.githubusercontent.com/\(owner)/\(repoName)/main/manifest.json")!
        
        do {
            let (data, _) = try await URLSession.shared.data(from: manifestURL)
            let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)
            
            let plugin = Plugin(
                id: manifest.id,
                name: manifest.name,
                description: manifest.description ?? "Custom plugin",
                repoUrl: "\(cleanURL).git"
            )
            
            // Check if already exists
            if discoveredPlugins.contains(where: { $0.id == plugin.id }) {
                addLog("⚠ Plugin '\(plugin.name)' already in list")
            } else {
                discoveredPlugins.append(plugin)
                selectedPlugins.insert(plugin.id)
                addLog("✓ Added custom plugin: \(plugin.name)")
            }
            
            customRepoURL = ""
            
        } catch {
            // Fallback: add without manifest
            let plugin = Plugin(
                id: repoName,
                name: repoName,
                description: "Custom plugin (no manifest found)",
                repoUrl: "\(cleanURL).git"
            )
            
            discoveredPlugins.append(plugin)
            selectedPlugins.insert(plugin.id)
            customRepoURL = ""
            addLog("⚠ Added custom plugin without manifest: \(repoName)")
        }
    }
    
    // MARK: - Installation
    
    func install() async {
        let pluginsToInstall = discoveredPlugins.filter { selectedPlugins.contains($0.id) }
        let vaultsToInstall = availableVaults.filter { selectedVaults.contains($0.id) }
        
        guard !pluginsToInstall.isEmpty && !vaultsToInstall.isEmpty else {
            addLog("✗ No plugins or vaults selected")
            return
        }
        
        currentStep = .installing
        
        addLog("\n🚀 Starting installation...")
        addLog("Plugins: \(pluginsToInstall.count)")
        addLog("Vaults: \(vaultsToInstall.count)")
        addLog("")
        
        var successCount = 0
        var failCount = 0
        let totalOperations = pluginsToInstall.count * vaultsToInstall.count
        var currentOperation = 0
        
        for vault in vaultsToInstall {
            addLog("📂 Vault: \(vault.name)")
            
            let pluginDir = "\(vault.path)/.obsidian/plugins"
            
            // Create plugins directory if needed
            try? FileManager.default.createDirectory(
                atPath: pluginDir,
                withIntermediateDirectories: true
            )
            
            for plugin in pluginsToInstall {
                currentOperation += 1
                installationStatus = .installing(
                    current: currentOperation,
                    total: totalOperations,
                    message: "Installing \(plugin.name) to \(vault.name)..."
                )
                
                let targetDir = "\(pluginDir)/\(plugin.id)"
                
                do {
                    if FileManager.default.fileExists(atPath: targetDir) {
                        addLog("  ↻ Updating \(plugin.name)...")
                        try await updatePlugin(at: targetDir)
                    } else {
                        addLog("  ⬇ Installing \(plugin.name)...")
                        try await clonePlugin(url: plugin.repoUrl, to: targetDir)
                    }
                    
                    // Check if build is needed
                    try await buildPluginIfNeeded(at: targetDir, name: plugin.name)
                    
                    addLog("  ✓ Done")
                    successCount += 1
                    
                } catch {
                    addLog("  ✗ Failed: \(error.localizedDescription)")
                    failCount += 1
                }
            }
            
            addLog("")
        }
        
        installationStatus = .completed(success: successCount, failed: failCount)
        addLog("🎉 Installation complete!")
        addLog("✓ Success: \(successCount)")
        if failCount > 0 {
            addLog("✗ Failed: \(failCount)")
        }
        addLog("\nPlease restart Obsidian or reload plugins.")
    }
    
    private func clonePlugin(url: String, to path: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["clone", url, path]
        
        let pipe = Pipe()
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "git", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: error])
        }
    }
    
    private func updatePlugin(at path: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["pull"]
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "git", code: Int(process.terminationStatus))
        }
    }
    
    private func buildPluginIfNeeded(at path: String, name: String) async throws {
        let mainJsPath = "\(path)/main.js"
        let packageJsonPath = "\(path)/package.json"
        
        // If main.js exists, no build needed
        if FileManager.default.fileExists(atPath: mainJsPath) {
            return
        }
        
        // If no package.json, no build possible
        guard FileManager.default.fileExists(atPath: packageJsonPath) else {
            return
        }
        
        addLog("    🔨 Building \(name)...")
        
        // Check if npm is available
        guard FileManager.default.fileExists(atPath: "/usr/local/bin/npm") ||
              FileManager.default.fileExists(atPath: "/opt/homebrew/bin/npm") else {
            addLog("    ⚠ npm not found, skipping build")
            return
        }
        
        // Run npm install
        try await runCommand("/bin/sh", args: ["-c", "cd '\(path)' && npm install --silent"])
        
        // Run npm build
        try await runCommand("/bin/sh", args: ["-c", "cd '\(path)' && npm run build --silent"])
        
        if FileManager.default.fileExists(atPath: mainJsPath) {
            addLog("    ✓ Build successful")
        } else {
            addLog("    ⚠ Build completed but main.js not found")
        }
    }
    
    private func runCommand(_ command: String, args: [String]) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "command", code: Int(process.terminationStatus))
        }
    }
    
    // MARK: - Navigation
    
    func canContinue() -> Bool {
        switch currentStep {
        case .selectPlugins:
            return !selectedPlugins.isEmpty
        case .selectVaults:
            return !selectedVaults.isEmpty
        case .confirm:
            return true
        case .installing:
            return false
        }
    }
    
    func nextStep() {
        if let next = InstallStep(rawValue: currentStep.rawValue + 1) {
            currentStep = next
        }
    }
    
    func previousStep() {
        if let previous = InstallStep(rawValue: currentStep.rawValue - 1) {
            currentStep = previous
        }
    }
    
    // MARK: - Logging
    
    private func addLog(_ message: String) {
        installationLog.append(message)
    }
    
    // MARK: - Helper Models
    
    private struct GitHubRepo: Codable {
        let name: String
        let cloneUrl: String
        
        enum CodingKeys: String, CodingKey {
            case name
            case cloneUrl = "clone_url"
        }
    }
    
    private struct PluginManifest: Codable {
        let id: String
        let name: String
        let description: String?
    }
}
