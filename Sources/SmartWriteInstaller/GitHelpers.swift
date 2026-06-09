// ==============================================================================
// SCRIPT: GitHelpers.swift
// DESCRIÇÃO: Utilitários estáticos compartilhados de operações Git, build de
//            plugins e detecção de vaults do Obsidian. Centraliza a lógica
//            duplicada entre os ViewModels e garante ponto único de manutenção.
// CHAMADO POR: InstallerViewModel.swift, VaultCopierViewModel.swift
// TRAZ (CHAMA/IMPORTA): Foundation, Process → /usr/bin/git, /bin/sh (npm)
// CONTRATO (RESPOSTA ESPERADA): Funções estáticas que executam operações de
//            sistema (git clone, git pull, npm build) e leitura de obsidian.json.
//            Erros são sempre propagados via throw para o chamador tratar e logar.
// ==============================================================================

import Foundation

// MARK: - GitHelper

/// Utilitários estáticos de operações Git, build de plugins e detecção de vaults.
/// Todas as funções são thread-safe e podem ser chamadas de contextos `async`.
enum GitHelper {

    // MARK: - Detecção de Vaults

    /// Lê o arquivo `obsidian.json` e retorna os vaults registrados que existem no disco.
    /// Retorna array vazio (sem throw) se o arquivo de config não for encontrado.
    ///
    /// - Parameter configPath: Caminho absoluto para o `obsidian.json` do Obsidian
    /// - Returns: Array de `ObsidianVault` validados e existentes no sistema de arquivos
    /// - Throws: Erros de leitura de dados ou falha na decodificação do JSON
    static func detectVaults(fromConfigAt configPath: String) throws -> [ObsidianVault] {
        let fileManager = FileManager.default

        // Se o arquivo de configuração não existe, retorna lista vazia sem erro —
        // o Obsidian pode nunca ter sido aberto na máquina ou o caminho mudou.
        guard fileManager.fileExists(atPath: configPath) else { return [] }

        let data   = try Data(contentsOf: URL(fileURLWithPath: configPath))
        let config = try JSONDecoder().decode(ObsidianConfig.self, from: data)

        // Filtra entradas cujo diretório não existe mais no disco (vaults removidos/movidos)
        return config.vaults.values.compactMap { info -> ObsidianVault? in
            let expandedPath = NSString(string: info.path).expandingTildeInPath
            guard fileManager.fileExists(atPath: expandedPath) else { return nil }
            return ObsidianVault(path: expandedPath)
        }
    }

    // MARK: - Operações Git

    /// Clona um repositório remoto para um diretório local via `git clone`.
    ///
    /// - Parameters:
    ///   - url: URL completa do repositório (ex: `https://github.com/user/repo.git`)
    ///   - path: Caminho absoluto do diretório de destino (não deve existir previamente)
    /// - Throws: `NSError` com a mensagem de stderr do git em caso de falha
    static func clonePlugin(url: String, to path: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments     = ["clone", url, path]

        // Captura stderr para fornecer mensagem de erro informativa ao usuário
        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data         = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: data, encoding: .utf8) ?? "Erro desconhecido no git clone"
            throw NSError(domain: "git.clone", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
    }

    /// Atualiza um plugin existente via `git pull` no diretório especificado.
    ///
    /// - Parameter path: Caminho absoluto do diretório do plugin (repositório git local)
    /// - Throws: `NSError` com o código de saída se o `git pull` falhar
    static func updatePlugin(at path: String) async throws {
        try await runProcess(
            executablePath:   "/usr/bin/git",
            arguments:        ["pull"],
            workingDirectory: path
        )
    }

    // MARK: - Build de Plugins

    /// Verifica se um plugin precisa ser compilado e executa `npm install` + `npm run build`.
    /// A compilação só ocorre quando `main.js` não existe mas `package.json` está presente.
    ///
    /// - Parameters:
    ///   - path: Caminho absoluto do diretório raiz do plugin
    ///   - name: Nome do plugin para exibição nas mensagens de log
    ///   - log:  Closure chamada para cada linha de log gerada durante o processo de build
    /// - Throws: `NSError` se `npm install` ou `npm run build` retornarem código de erro
    static func buildPluginIfNeeded(at path: String, name: String, log: (String) -> Void) async throws {
        let mainJsPath      = "\(path)/main.js"
        let packageJsonPath = "\(path)/package.json"

        // Se main.js já existe, o plugin está compilado — não recompilar desnecessariamente
        if FileManager.default.fileExists(atPath: mainJsPath) { return }

        // Sem package.json não há script de build — plugin pode ser JavaScript puro
        guard FileManager.default.fileExists(atPath: packageJsonPath) else { return }

        // Verifica npm nos caminhos padrão do macOS (Homebrew Apple Silicon e Intel/nvm)
        let npmPaths = ["/usr/local/bin/npm", "/opt/homebrew/bin/npm"]
        guard npmPaths.contains(where: { FileManager.default.fileExists(atPath: $0) }) else {
            log("    ⚠ npm não encontrado — compilação ignorada para \(name)")
            return
        }

        log("    🔨 Compilando \(name)...")

        // Instala dependências declaradas no package.json
        try await runProcess(executablePath: "/bin/sh",
                             arguments: ["-c", "cd '\(path)' && npm install --silent"])

        // Executa o script de build (normalmente gera main.js via esbuild/rollup)
        try await runProcess(executablePath: "/bin/sh",
                             arguments: ["-c", "cd '\(path)' && npm run build --silent"])

        // Confirma se o artefato principal foi gerado com sucesso
        if FileManager.default.fileExists(atPath: mainJsPath) {
            log("    ✓ Compilação concluída: \(name)")
        } else {
            log("    ⚠ Build finalizado mas main.js não encontrado: \(name)")
        }
    }

    // MARK: - Utilitário Interno de Processo

    /// Executa um processo do sistema e aguarda sua conclusão.
    /// Lança erro se o processo encerrar com código diferente de zero.
    ///
    /// - Parameters:
    ///   - executablePath:   Caminho completo do executável (ex: `/usr/bin/git`)
    ///   - arguments:        Lista de argumentos a passar ao processo
    ///   - workingDirectory: Diretório de trabalho opcional (padrão: diretório atual)
    /// - Throws: `NSError` com o código de saída do processo em caso de falha
    static func runProcess(
        executablePath:   String,
        arguments:        [String],
        workingDirectory: String? = nil
    ) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments     = arguments

        if let cwd = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }

        try process.run()
        process.waitUntilExit()

        // Qualquer código de saída diferente de zero indica falha da operação
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "process.error",
                code:   Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey: "Processo falhou (código \(process.terminationStatus)): \(executablePath) \(arguments.joined(separator: " "))"
                ]
            )
        }
    }
}
