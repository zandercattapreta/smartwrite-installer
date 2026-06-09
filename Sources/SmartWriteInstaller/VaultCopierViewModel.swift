// ==============================================================================
// SCRIPT: VaultCopierViewModel.swift
// DESCRIÇÃO: ViewModel do módulo de cópia de vault. Gerencia o fluxo de
//            seleção de vault de origem, destino(s) e opções de cópia
//            (plugins, preferências, snippets, lista de plugins ativos).
//            Antes de copiar, atualiza via git pull os plugins com repositório
//            local e re-builda se necessário.
// CHAMADO POR: ContentView.swift → VaultCopierTabView
// TRAZ (CHAMA/IMPORTA): Foundation, GitHelpers.swift (GitHelper), FileManager
// CONTRATO (RESPOSTA ESPERADA): Publica estado reativo via @Published.
//            Gerencia o ciclo: origem → destino → opções → progresso de cópia.
// ==============================================================================

import Foundation

@MainActor
class VaultCopierViewModel: ObservableObject {
    @Published var availableVaults: [ObsidianVault] = []
    @Published var sourceVault: ObsidianVault? = nil
    @Published var targetVaults: Set<UUID> = []

    /// Opções de itens a serem copiados do vault de origem para o(s) destino(s).
    struct CopyOptions: Equatable {
        var plugins: Bool       = true   // Pasta .obsidian/plugins completa
        var preferences: Bool   = true   // Arquivos JSON de preferências do Obsidian
        var snippets: Bool      = true   // Pasta .obsidian/snippets (CSS personalizado)
        var activePlugins: Bool = true   // Lista de plugins ativos (community-plugins.json)
    }

    @Published var copyOptions = CopyOptions()

    enum CopierStep: Int, CaseIterable {
        case selectSource  = 0
        case selectTarget  = 1
        case selectOptions = 2
        case copying       = 3

        var title: String {
            switch self {
            case .selectSource:  return "Vault de Origem"
            case .selectTarget:  return "Vault de Destino"
            case .selectOptions: return "O que copiar"
            case .copying:       return "Progresso"
            }
        }

        var description: String {
            switch self {
            case .selectSource:  return "Escolha o vault base"
            case .selectTarget:  return "Escolha o vault de destino"
            case .selectOptions: return "Selecione os itens para copiar"
            case .copying:       return "Copiando arquivos..."
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

    // Caminho padrão do arquivo de configuração do Obsidian no macOS
    private let obsidianConfigPath = "\(NSHomeDirectory())/Library/Application Support/obsidian/obsidian.json"

    // MARK: - Detecção de Vaults

    /// Detecta os vaults do Obsidian e atualiza `availableVaults`.
    /// Mantém a ordenação alfabética e limpa seleções inválidas após cada chamada.
    func detectVaults() {
        do {
            // Obtém a lista bruta de vaults via utilitário compartilhado
            let vaults = try GitHelper.detectVaults(fromConfigAt: obsidianConfigPath)

            // Ordena alfabeticamente para consistência visual na lista
            availableVaults = vaults.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

            // Remove o vault de origem se ele não existir mais na lista atualizada
            if let src = sourceVault, !availableVaults.contains(where: { $0.id == src.id }) {
                sourceVault = nil
            }

            // Remove vaults de destino que foram removidos ou que passaram a ser o source
            targetVaults.formIntersection(availableVaults.map { $0.id })
            if let srcId = sourceVault?.id {
                targetVaults.remove(srcId)
            }

        } catch {
            // Erro silencioso — a UI exibirá lista vazia permitindo seleção manual
            print("Erro ao detectar vaults: \(error.localizedDescription)")
        }
    }

    // MARK: - Navegação

    /// Indica se o usuário pode avançar para o próximo passo do wizard de cópia.
    func canContinue() -> Bool {
        switch currentStep {
        case .selectSource:  return sourceVault != nil
        case .selectTarget:  return !targetVaults.isEmpty
        case .selectOptions: return copyOptions.plugins || copyOptions.preferences
                                 || copyOptions.snippets || copyOptions.activePlugins
        case .copying:       return false
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

    // MARK: - Log Interno

    private func addLog(_ message: String) {
        copyLog.append(message)
    }

    // MARK: - Execução da Cópia

    /// Executa a cópia dos itens selecionados do vault de origem para cada vault de destino.
    ///
    /// Fluxo:
    /// 1. Pré-verificação: atualiza plugins Git no vault de origem antes de copiar
    /// 2. Para cada vault de destino: copia plugins, preferências, snippets e lista de ativos
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

        let fm             = FileManager.default
        let sourceObsidian = "\(source.path)/.obsidian"

        var successCount = 0
        var failCount    = 0

        // ── Fase 1: Pré-verificação de Plugins no vault de origem ─────────────
        // Atualiza via git pull os plugins que possuem repositório local antes de
        // copiar, garantindo que o destino receba a versão mais recente do código.
        if copyOptions.plugins {
            copyStatus = .copying(current: 0, total: 1,
                                  message: "Verificando atualizações nos plugins de origem...")
            addLog("🔍 Verificando repositórios locais para atualização...")

            // Pausa mínima para que a view registre a mudança de estado antes do trabalho pesado
            try? await Task.sleep(nanoseconds: 500_000_000)

            if let pluginFolders = try? fm.contentsOfDirectory(atPath: "\(sourceObsidian)/plugins") {
                for pluginName in pluginFolders where !pluginName.hasPrefix(".") {
                    let pluginPath = "\(sourceObsidian)/plugins/\(pluginName)"
                    let gitPath    = "\(pluginPath)/.git"

                    if fm.fileExists(atPath: gitPath) {
                        addLog("  ↻ Atualizando via git: \(pluginName)...")
                        do {
                            try await GitHelper.updatePlugin(at: pluginPath)
                            try await GitHelper.buildPluginIfNeeded(at: pluginPath, name: pluginName) { self.addLog($0) }
                        } catch {
                            addLog("  ⚠ Falha ao atualizar \(pluginName) na origem.")
                        }
                    }
                    // Plugins sem .git (instalados pelo Obsidian Community) são ignorados —
                    // o Obsidian é responsável por atualizá-los via sua própria interface.

                    // Pausa mínima para animar o log em tempo real na UI
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
            }
        }

        // ── Cálculo do total de operações (para a barra de progresso) ────────
        var totalOperations = 0
        if copyOptions.plugins {
            if let pluginFolders = try? fm.contentsOfDirectory(atPath: "\(sourceObsidian)/plugins") {
                totalOperations += pluginFolders.filter { !$0.hasPrefix(".") }.count
            }
        }
        if copyOptions.preferences  { totalOperations += 1 }
        if copyOptions.snippets     { totalOperations += 1 }
        if copyOptions.activePlugins { totalOperations += 1 }
        totalOperations *= targets.count

        var currentOperation = 0

        try? await Task.sleep(nanoseconds: 500_000_000)

        // ── Fase 2: Loop de cópia por vault de destino ────────────────────────
        for target in targets {
            addLog("📂 Vault de Destino: \(target.name)")
            let targetObsidian = "\(target.path)/.obsidian"

            // Garante que o diretório .obsidian existe no vault de destino
            if !fm.fileExists(atPath: targetObsidian) {
                try? fm.createDirectory(atPath: targetObsidian, withIntermediateDirectories: true)
            }

            /// Copia um item do .obsidian de origem para o de destino.
            /// Remove o item no destino antes de copiar para garantir consistência.
            func copy(itemName: String, message: String, incrementOp: Bool = true) {
                if incrementOp { currentOperation += 1 }
                copyStatus = .copying(current: currentOperation, total: totalOperations,
                                      message: "\(target.name): \(message)")

                let sourcePath = "\(sourceObsidian)/\(itemName)"
                let targetPath = "\(targetObsidian)/\(itemName)"

                guard fm.fileExists(atPath: sourcePath) else {
                    addLog("  ℹ Não encontrado na origem: \(itemName)")
                    return
                }

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
            }

            // Cópia de plugins (pasta a pasta, individualmente)
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
                        guard !pluginName.hasPrefix(".") else { continue }

                        let srcPluginPath = "\(sourcePluginsDir)/\(pluginName)"
                        let tgtPluginPath = "\(targetPluginsDir)/\(pluginName)"

                        var isDir: ObjCBool = false
                        guard fm.fileExists(atPath: srcPluginPath, isDirectory: &isDir),
                              isDir.boolValue else { continue }

                        currentOperation += 1
                        copyStatus = .copying(current: currentOperation, total: totalOperations,
                                              message: "\(target.name): Copiando \(pluginName)...")
                        addLog("    📦 \(pluginName)")

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
                } catch {
                    addLog("    ✗ Erro ao ler plugins: \(error.localizedDescription)")
                    failCount += 1
                }
            }

            // Cópia de preferências individuais do Obsidian
            if copyOptions.preferences {
                addLog("  ⚙ Copiando preferências...")
                let prefs = ["app.json", "appearance.json", "hotkeys.json", "core-plugins.json"]
                for pref in prefs {
                    copy(itemName: pref, message: "Copiando \(pref)...", incrementOp: false)
                }
                currentOperation += 1
            }

            // Cópia da pasta de snippets CSS personalizados
            if copyOptions.snippets {
                addLog("  🎨 Copiando snippets CSS...")
                copy(itemName: "snippets", message: "Copiando snippets...")
            }

            // Cópia da lista de plugins ativos (community-plugins.json)
            if copyOptions.activePlugins {
                addLog("  📋 Copiando lista de plugins ativos...")
                copy(itemName: "community-plugins.json", message: "Copiando community-plugins.json...")
            }

            addLog("")
        }

        copyStatus = .completed(success: successCount, failed: failCount)
    }
}
