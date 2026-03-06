import Foundation

@MainActor
class VaultCopierViewModel: ObservableObject {
    @Published var availableVaults: [ObsidianVault] = []
    @Published var sourceVault: ObsidianVault? = nil
    @Published var targetVaults: Set<UUID> = []
    
    struct CopyOptions: Equatable {
        var plugins: Bool = true
        var preferences: Bool = true
        var snippets: Bool = true
        var activePlugins: Bool = true
    }
    
    @Published var copyOptions = CopyOptions()
    
    enum CopierStep: Int, CaseIterable {
        case selectSource = 0
        case selectTarget = 1
        case selectOptions = 2
        case copying = 3
        
        var title: String {
            switch self {
            case .selectSource: return "Vault de Origem"
            case .selectTarget: return "Vault de Destino"
            case .selectOptions: return "O que copiar"
            case .copying: return "Progresso"
            }
        }
        
        var description: String {
            switch self {
            case .selectSource: return "Escolha o vault base"
            case .selectTarget: return "Escolha o vault de destino"
            case .selectOptions: return "Selecione os itens para copiar"
            case .copying: return "Copiando arquivos..."
            }
        }
    }
    
    enum CopyStatus: Equatable {
        case idle
        case copying(current: Int, total: Int, message: String)
        case completed(success: Int, failed: Int)
        case failed(String)
    }
    
    @Published var currentStep: CopierStep = .selectSource
    @Published var copyLog: [String] = []
    @Published var copyStatus: CopyStatus = .idle
    
    private let obsidianConfigPath = "\(NSHomeDirectory())/Library/Application Support/obsidian/obsidian.json"
    
    func detectVaults() {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: obsidianConfigPath) else {
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
            
            availableVaults = vaults.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
            
            if let src = sourceVault, !availableVaults.contains(where: { $0.id == src.id }) {
                sourceVault = nil
            }
            // Remove vaults de destino que não existem mais ou que por acaso sejam o source
            targetVaults.formIntersection(availableVaults.map { $0.id })
            if let srcId = sourceVault?.id {
                targetVaults.remove(srcId)
            }
            
            
        } catch {
            print("Error parsing obsidian config: \(error)")
        }
    }
    
    func canContinue() -> Bool {
        switch currentStep {
        case .selectSource:
            return sourceVault != nil
        case .selectTarget:
            return !targetVaults.isEmpty
        case .selectOptions:
            return copyOptions.plugins || copyOptions.preferences || copyOptions.snippets || copyOptions.activePlugins
        case .copying:
            return false
        }
    }
    
    func nextStep() {
        if let next = CopierStep(rawValue: currentStep.rawValue + 1) {
            currentStep = next
        }
    }
    
    func previousStep() {
        if let previous = CopierStep(rawValue: currentStep.rawValue - 1) {
            currentStep = previous
        }
    }
    
    private func addLog(_ message: String) {
        copyLog.append(message)
    }
    
    func startCopy() async {
        guard let source = sourceVault else { return }
        
        let targets = availableVaults.filter { targetVaults.contains($0.id) }
        guard !targets.isEmpty else { return }
        
        currentStep = .copying
        copyLog.removeAll()
        addLog("🚀 Iniciando cópia...")
        addLog("De: \(source.name)")
        addLog("Para \(targets.count) vault(s)")
        addLog("")
        
        let fm = FileManager.default
        let sourceObsidian = "\(source.path)/.obsidian"
        
        var successCount = 0
        var failCount = 0
        
        // Fase 1: Pré-verificação de Plugins no source
        if copyOptions.plugins {
            copyStatus = .copying(current: 0, total: 1, message: "Verificando se há atualizações pendentes nos plugins de origem...")
            addLog("🔍 Verificando repositórios locais para atualização...")
            
            // Pausa rápida para a view registrar a intent
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            if let pluginFolders = try? fm.contentsOfDirectory(atPath: "\(sourceObsidian)/plugins") {
                let validPlugins = pluginFolders.filter { !$0.hasPrefix(".") }
                for pluginName in validPlugins {
                    let gitPath = "\(sourceObsidian)/plugins/\(pluginName)/.git"
                    if fm.fileExists(atPath: gitPath) {
                        addLog("  ↻ Verificando repo Git: \(pluginName)...")
                        do {
                            try await updatePlugin(at: "\(sourceObsidian)/plugins/\(pluginName)")
                            try await buildPluginIfNeeded(at: "\(sourceObsidian)/plugins/\(pluginName)", name: pluginName)
                        } catch {
                            addLog("  ⚠ Falha ao atualizar \(pluginName) na origem.")
                        }
                    } else {
                        // É um plugin que não tem .git (foi baixado normalmente pelo Obsidian Community list)
                        // Apenas ignoramos silenciosamente a atualização, mas podemos pausar micro-segundos para a UI
                        // addLog("  - \(pluginName) (Plugin nativo/estático)")
                    }
                    // Força pequena pausa pro log animar na tela em tempo real
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
            }
        }
        
        // Calcular total de operações base (antes do loop para n destinos)
        var totalOperations = 0
        if copyOptions.plugins {
            if let pluginFolders = try? fm.contentsOfDirectory(atPath: "\(sourceObsidian)/plugins") {
                let validPlugins = pluginFolders.filter { !$0.hasPrefix(".") }
                totalOperations += validPlugins.count
            }
        }
        if copyOptions.preferences { totalOperations += 1 }
        if copyOptions.snippets { totalOperations += 1 }
        if copyOptions.activePlugins { totalOperations += 1 }
        
        totalOperations *= targets.count
        var currentOperation = 0
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        for target in targets {
            addLog("📂 Vault de Destino: \(target.name)")
            let targetObsidian = "\(target.path)/.obsidian"
            
            if !fm.fileExists(atPath: targetObsidian) {
                try? fm.createDirectory(atPath: targetObsidian, withIntermediateDirectories: true)
            }
            
            func copy(itemName: String, message: String, incrementOp: Bool = true) {
                if incrementOp {
                    currentOperation += 1
                }
                copyStatus = .copying(current: currentOperation, total: totalOperations, message: "\(target.name): \(message)")
                
                let sourcePath = "\(sourceObsidian)/\(itemName)"
                let targetPath = "\(targetObsidian)/\(itemName)"
                
                if fm.fileExists(atPath: sourcePath) {
                    do {
                        if fm.fileExists(atPath: targetPath) {
                            try fm.removeItem(atPath: targetPath)
                        }
                        try fm.copyItem(atPath: sourcePath, toPath: targetPath)
                        addLog("  ✓ Copiado: \(itemName)")
                        successCount += 1
                    } catch {
                        addLog("  ✗ Erro ao copiar \(itemName): \(error.localizedDescription)")
                        failCount += 1
                    }
                } else {
                    addLog("  ℹ Não encontrado na origem: \(itemName)")
                }
            }
            
            if copyOptions.plugins {
                addLog("  📁 Processando plugins...")
                let sourcePluginsDir = "\(sourceObsidian)/plugins"
                let targetPluginsDir = "\(targetObsidian)/plugins"
                
                if !fm.fileExists(atPath: targetPluginsDir) {
                    try? fm.createDirectory(atPath: targetPluginsDir, withIntermediateDirectories: true)
                }
                
                do {
                    let pluginFolders = try fm.contentsOfDirectory(atPath: sourcePluginsDir)
                    for pluginName in pluginFolders {
                        if pluginName.hasPrefix(".") { continue }
                        
                        let srcPluginPath = "\(sourcePluginsDir)/\(pluginName)"
                        let tgtPluginPath = "\(targetPluginsDir)/\(pluginName)"
                        
                        var isDir: ObjCBool = false
                        if fm.fileExists(atPath: srcPluginPath, isDirectory: &isDir), isDir.boolValue {
                            currentOperation += 1
                            copyStatus = .copying(current: currentOperation, total: totalOperations, message: "\(target.name): Copiando \(pluginName)...")
                            
                            addLog("    📦 \(pluginName)")
                            
                            // (Atualização git e build da origem já foi feita no passo de pré-verificação)
                            
                            do {
                                if fm.fileExists(atPath: tgtPluginPath) {
                                    try fm.removeItem(atPath: tgtPluginPath)
                                }
                                try fm.copyItem(atPath: srcPluginPath, toPath: tgtPluginPath)
                                addLog("      ✓ Ok")
                                successCount += 1
                            } catch {
                                addLog("      ✗ Falha: \(error.localizedDescription)")
                                failCount += 1
                            }
                        }
                    }
                } catch {
                    addLog("    ✗ Erro ao ler plugins: \(error.localizedDescription)")
                    failCount += 1
                }
            }
            
            if copyOptions.preferences {
                addLog("  ⚙ Copiando preferências...")
                let prefs = ["app.json", "appearance.json", "hotkeys.json", "core-plugins.json"]
                for pref in prefs {
                    copy(itemName: pref, message: "Copiando \(pref)...", incrementOp: false)
                }
                currentOperation += 1 // Incrementa na conta final do grupo de prefs
            }
            
            if copyOptions.snippets {
                addLog("  🎨 Copiando snippets CSS...")
                copy(itemName: "snippets", message: "Copiando snippets...")
            }
            
            if copyOptions.activePlugins {
                addLog("  📋 Copiando lista de plugins ativos...")
                copy(itemName: "community-plugins.json", message: "Copiando community-plugins.json...")
            }
            addLog("")
        }
        
        // A cópia de plugins e configurações foi transferida para dentro do loop `for target`,
        // portanto estes blocos antigos finais não são mais necessários aqui.
        
        copyStatus = .completed(success: successCount, failed: failCount)
    }
    
    // MARK: - Git & Build Helpers
    
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
        
        // Se já existe main.js, não re-buildamos automaticamente por segurança 
        // (assume-se que o git pull traria o main.js atualizado se o dev asssim publicou)
        // Mas se package.json existe e main.js NÃO, é um plugin de source-only:
        guard FileManager.default.fileExists(atPath: packageJsonPath) else { return }
        
        // Vamos forçar build apenas se atualizou ou não tinha build antes
        addLog("    🔨 Compilando recursos (\(name))...")
        
        guard FileManager.default.fileExists(atPath: "/usr/local/bin/npm") ||
              FileManager.default.fileExists(atPath: "/opt/homebrew/bin/npm") else {
            addLog("    ⚠ npm não encontrado, pulando compilação")
            return
        }
        
        try await runCommand("/bin/sh", args: ["-c", "cd '\(path)' && npm install --silent"])
        try await runCommand("/bin/sh", args: ["-c", "cd '\(path)' && npm run build --silent"])
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
}
