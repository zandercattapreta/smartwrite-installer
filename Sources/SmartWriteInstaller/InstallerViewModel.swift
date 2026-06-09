// ==============================================================================
// SCRIPT: InstallerViewModel.swift
// DESCRIÇÃO: ViewModel principal do fluxo de instalação de plugins SmartWrite.
//            Orquestra a descoberta de plugins via GitHub API, a detecção de
//            vaults do Obsidian e a instalação via git clone/pull com build
//            automático de dependências npm quando necessário.
// CHAMADO POR: ContentView.swift → InstallerTabView
// TRAZ (CHAMA/IMPORTA): Foundation, GitHelpers.swift (GitHelper),
//            URLSession (GitHub API), FileManager, Process via GitHelper
// CONTRATO (RESPOSTA ESPERADA): Publica estado reativo via @Published para a UI
//            de wizard multi-step. Gerencia o ciclo completo: descoberta →
//            seleção de plugins → seleção de vault → confirmação → instalação.
// ==============================================================================

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

    // Proprietário dos repositórios SmartWrite no GitHub
    private let repoOwner = "zandercpzed"

    // Caminho padrão do arquivo de configuração do Obsidian no macOS
    private let obsidianConfigPath = "\(NSHomeDirectory())/Library/Application Support/obsidian/obsidian.json"

    enum InstallStep: Int, CaseIterable {
        case selectPlugins = 0
        case selectVaults  = 1
        case confirm       = 2
        case installing    = 3

        var title: String {
            switch self {
            case .selectPlugins: return "Selecionar Plugins"
            case .selectVaults:  return "Selecionar Vaults"
            case .confirm:       return "Confirmar Instalação"
            case .installing:    return "Instalando"
            }
        }

        var description: String {
            switch self {
            case .selectPlugins: return "Escolha quais plugins SmartWrite instalar"
            case .selectVaults:  return "Escolha em quais vaults do Obsidian instalar"
            case .confirm:       return "Revise suas seleções antes de instalar"
            case .installing:    return "Instalando plugins nos seus vaults"
            }
        }
    }

    // MARK: - Descoberta de Plugins

    /// Descobre os plugins SmartWrite disponíveis consultando a API pública do GitHub.
    /// Filtra repositórios pelo padrão de nome e valida a presença de `manifest.json`.
    func discoverPlugins() async {
        installationStatus = .discovering
        addLog("🔍 Descobrindo plugins SmartWrite do GitHub...")

        do {
            // Busca todos os repositórios públicos do owner (limite: 100 por página)
            let url = URL(string: "https://api.github.com/users/\(repoOwner)/repos?per_page=100")!
            let (data, _) = try await URLSession.shared.data(from: url)

            let repos = try JSONDecoder().decode([GitHubRepo].self, from: data)

            // Filtra repositórios com prefixo smartwrite- ou smartwriter-,
            // excluindo o próprio instalador para evitar auto-referência circular
            let smartWriteRepos = repos
                .filter { $0.name.hasPrefix("smartwrite-") || $0.name.hasPrefix("smartwriter-") }
                .filter { $0.name != "smartwrite-installer" }

            addLog("✓ Encontrou \(smartWriteRepos.count) repositórios")

            // Busca o manifest.json de cada repositório para extrair metadados oficiais
            var plugins: [Plugin] = []
            for repo in smartWriteRepos {
                if let plugin = await fetchPluginManifest(repo: repo) {
                    plugins.append(plugin)
                    addLog("  → \(plugin.name)")
                }
            }

            discoveredPlugins = plugins
            installationStatus = .idle
            addLog("✓ Descoberta concluída! Encontrou \(plugins.count) plugins válidos")

        } catch {
            installationStatus = .failed("Falha ao descobrir plugins: \(error.localizedDescription)")
            addLog("✗ Erro: \(error.localizedDescription)")
        }
    }

    /// Busca e decodifica o `manifest.json` de um repositório para obter os metadados do plugin.
    /// Retorna `nil` silenciosamente se o repositório não possuir manifesto válido.
    private func fetchPluginManifest(repo: GitHubRepo) async -> Plugin? {
        let manifestURL = URL(string: "https://raw.githubusercontent.com/\(repoOwner)/\(repo.name)/main/manifest.json")!

        do {
            let (data, _) = try await URLSession.shared.data(from: manifestURL)
            let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)

            return Plugin(
                id:          manifest.id,
                name:        manifest.name,
                description: manifest.description ?? "Nenhuma descrição disponível",
                repoUrl:     repo.cloneUrl
            )
        } catch {
            // Repositórios sem manifest.json válido são ignorados silenciosamente
            return nil
        }
    }

    // MARK: - Detecção de Vaults

    /// Detecta os vaults do Obsidian registrados na máquina lendo o `obsidian.json`.
    /// Delega a lógica de leitura ao `GitHelper` como ponto único de implementação.
    func detectVaults() {
        addLog("🔍 Detectando vaults do Obsidian...")

        do {
            let vaults = try GitHelper.detectVaults(fromConfigAt: obsidianConfigPath)

            guard !vaults.isEmpty else {
                addLog("⚠ Nenhuma configuração do Obsidian encontrada no local padrão")
                return
            }

            availableVaults = vaults
            addLog("✓ Encontrou \(vaults.count) vault(s)")
            for vault in vaults { addLog("  → \(vault.name)") }

        } catch {
            addLog("✗ Erro ao ler a configuração do Obsidian: \(error.localizedDescription)")
        }
    }

    // MARK: - Vault Manual

    /// Adiciona um vault informado manualmente pelo usuário à lista de vaults disponíveis.
    /// Valida a existência do diretório no disco e evita duplicatas na lista.
    func addManualVault(path: String) {
        let expandedPath = NSString(string: path.trimmingCharacters(in: .whitespaces)).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            addLog("⚠ Caminho não encontrado: \(expandedPath)")
            return
        }

        let vault = ObsidianVault(path: expandedPath)

        guard !availableVaults.contains(where: { $0.path == expandedPath }) else {
            addLog("⚠ Vault já listado: \(vault.name)")
            return
        }

        availableVaults.append(vault)
        selectedVaults.insert(vault.id)
        addLog("✓ Vault adicionado manualmente: \(vault.name)")
    }

    // MARK: - Plugin Personalizado

    /// Adiciona um plugin a partir de uma URL de repositório GitHub informada pelo usuário.
    /// Tenta carregar o `manifest.json` remoto; se falhar, cadastra com metadados mínimos.
    func addCustomPlugin() async {
        guard !customRepoURL.isEmpty else { return }

        addLog("🔍 Verificando repositório personalizado: \(customRepoURL)")

        // Normaliza a URL: remove .git, espaços e barras finais
        var cleanURL = customRepoURL
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ".git", with: "")
        if cleanURL.hasSuffix("/") { cleanURL.removeLast() }

        // Extrai o segmento owner/repo da URL do GitHub
        guard let repoPath = cleanURL.components(separatedBy: "github.com/").last else {
            addLog("✗ URL do GitHub inválida")
            return
        }

        let parts = repoPath.split(separator: "/")
        guard parts.count >= 2 else {
            addLog("✗ Caminho do repositório inválido")
            return
        }

        let owner    = String(parts[0])
        let repoName = String(parts[1])

        // Tenta carregar o manifest.json para usar os metadados oficiais do plugin
        let manifestURL = URL(string: "https://raw.githubusercontent.com/\(owner)/\(repoName)/main/manifest.json")!

        do {
            let (data, _) = try await URLSession.shared.data(from: manifestURL)
            let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)

            let plugin = Plugin(
                id:          manifest.id,
                name:        manifest.name,
                description: manifest.description ?? "Plugin personalizado",
                repoUrl:     "\(cleanURL).git"
            )

            // Evita duplicatas — verifica se o plugin já está na lista pelo ID
            if discoveredPlugins.contains(where: { $0.id == plugin.id }) {
                addLog("⚠ O plugin '\(plugin.name)' já está na lista")
            } else {
                discoveredPlugins.append(plugin)
                selectedPlugins.insert(plugin.id)
                addLog("✓ Plugin personalizado adicionado: \(plugin.name)")
            }

            customRepoURL = ""

        } catch {
            // Fallback: registra o plugin sem manifest usando o nome do repositório como ID
            let plugin = Plugin(
                id:          repoName,
                name:        repoName,
                description: "Plugin personalizado (nenhum manifesto encontrado)",
                repoUrl:     "\(cleanURL).git"
            )

            discoveredPlugins.append(plugin)
            selectedPlugins.insert(plugin.id)
            customRepoURL = ""
            addLog("⚠ Plugin personalizado adicionado sem manifesto: \(repoName)")
        }
    }

    // MARK: - Instalação

    /// Executa a instalação dos plugins selecionados nos vaults escolhidos.
    /// Para cada par (plugin × vault): realiza `git clone` (novo) ou `git pull` (existente)
    /// e dispara build automático via `GitHelper` se `main.js` não estiver presente.
    func install() async {
        let pluginsToInstall = discoveredPlugins.filter { selectedPlugins.contains($0.id) }
        let vaultsToInstall  = availableVaults.filter { selectedVaults.contains($0.id) }

        guard !pluginsToInstall.isEmpty && !vaultsToInstall.isEmpty else {
            addLog("✗ Nenhum plugin ou vault selecionado")
            return
        }

        currentStep = .installing

        addLog("\n🚀 Iniciando instalação...")
        addLog("Plugins: \(pluginsToInstall.count)")
        addLog("Vaults: \(vaultsToInstall.count)")
        addLog("")

        var successCount     = 0
        var failCount        = 0
        let totalOperations  = pluginsToInstall.count * vaultsToInstall.count
        var currentOperation = 0

        for vault in vaultsToInstall {
            addLog("📂 Vault: \(vault.name)")

            let pluginDir = "\(vault.path)/.obsidian/plugins"

            // Garante que o diretório .obsidian/plugins existe antes de instalar
            try? FileManager.default.createDirectory(
                atPath: pluginDir,
                withIntermediateDirectories: true
            )

            for plugin in pluginsToInstall {
                currentOperation += 1
                installationStatus = .installing(
                    current: currentOperation,
                    total:   totalOperations,
                    message: "Instalando \(plugin.name) em \(vault.name)..."
                )

                let targetDir = "\(pluginDir)/\(plugin.id)"

                do {
                    if FileManager.default.fileExists(atPath: targetDir) {
                        addLog("  ↻ Atualizando \(plugin.name)...")
                        try await GitHelper.updatePlugin(at: targetDir)
                    } else {
                        addLog("  ⬇ Instalando \(plugin.name)...")
                        try await GitHelper.clonePlugin(url: plugin.repoUrl, to: targetDir)
                    }

                    // Compila o plugin caso main.js não esteja presente na branch clonada
                    try await GitHelper.buildPluginIfNeeded(at: targetDir, name: plugin.name) { self.addLog($0) }

                    addLog("  ✓ Concluído")
                    successCount += 1

                } catch {
                    addLog("  ✗ Falha: \(error.localizedDescription)")
                    failCount += 1
                }
            }

            addLog("")
        }

        installationStatus = .completed(success: successCount, failed: failCount)
        addLog("🎉 Instalação concluída!")
        addLog("✓ Sucesso: \(successCount)")
        if failCount > 0 { addLog("✗ Falha: \(failCount)") }
        addLog("\nPor favor, reinicie o Obsidian ou recarregue os plugins.")
    }

    // MARK: - Navegação

    /// Indica se o usuário pode avançar para o próximo passo do wizard.
    func canContinue() -> Bool {
        switch currentStep {
        case .selectPlugins: return !selectedPlugins.isEmpty
        case .selectVaults:  return !selectedVaults.isEmpty
        case .confirm:       return true
        case .installing:    return false
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

    // MARK: - Log Interno

    private func addLog(_ message: String) {
        installationLog.append(message)
    }

    // MARK: - Modelos Internos

    /// Representa um repositório retornado pela API REST do GitHub.
    private struct GitHubRepo: Codable {
        let name: String
        let cloneUrl: String

        enum CodingKeys: String, CodingKey {
            case name
            case cloneUrl = "clone_url"
        }
    }

    /// Representa o `manifest.json` nativo do Obsidian, usado para extrair metadados do plugin.
    private struct PluginManifest: Codable {
        let id: String
        let name: String
        let description: String?
    }
}
