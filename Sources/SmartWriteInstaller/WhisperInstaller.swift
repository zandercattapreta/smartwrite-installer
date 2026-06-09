import Foundation

/// Handles automatic installation of whisper.cpp (via Homebrew) and
/// downloading the default Whisper model for use with SmartWrite Dictation.
@MainActor
class WhisperInstaller {

    // MARK: - Public API

    /// Full setup: installs whisper-cpp via Homebrew and downloads the `small` model.
    /// Calls `onLog` with progress messages throughout.
    func setup(onLog: @escaping (String) -> Void) async {
        onLog("\n🎙 Configurando SmartWrite Dictation (whisper.cpp)...")

        // 1. Ensure Homebrew is available
        guard let brewPath = findBrew() else {
            onLog("  ⚠ Homebrew não encontrado. Instale em https://brew.sh e reabra o installer.")
            onLog("    O ditado ficará disponível após instalar o whisper-cpp manualmente:")
            onLog("    brew install whisper-cpp")
            return
        }

        onLog("  ✓ Homebrew encontrado em \(brewPath)")

        // 2. Check if whisper-cpp is already installed
        if isWhisperInstalled() {
            onLog("  ✓ whisper-cpp já instalado")
        } else {
            onLog("  ⬇ Instalando whisper-cpp via Homebrew... (pode demorar alguns minutos)")
            let installed = await installWhisperCpp(brewPath: brewPath, onLog: onLog)
            guard installed else { return }
            onLog("  ✓ whisper-cpp instalado com sucesso")
        }

        // 3. Download the `small` model if not present
        let modelPath = defaultModelPath()
        if FileManager.default.fileExists(atPath: modelPath) {
            onLog("  ✓ Modelo 'small' já disponível")
        } else {
            onLog("  ⬇ Baixando modelo Whisper 'small' (~466 MB)...")
            let downloaded = await downloadModel(onLog: onLog)
            if downloaded {
                onLog("  ✓ Modelo 'small' pronto em \(modelPath)")
            }
        }

        onLog("  🎙 Ditado configurado e pronto para uso!")
    }

    // MARK: - Homebrew

    private func findBrew() -> String? {
        let candidates = [
            "/opt/homebrew/bin/brew",   // Apple Silicon
            "/usr/local/bin/brew",       // Intel
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    private func isWhisperInstalled() -> Bool {
        let candidates = [
            "/opt/homebrew/bin/whisper-cli",
            "/usr/local/bin/whisper-cli",
        ]
        return candidates.contains { FileManager.default.fileExists(atPath: $0) }
    }

    private func installWhisperCpp(brewPath: String, onLog: @escaping (String) -> Void) async -> Bool {
        do {
            try await runProcess(
                executable: brewPath,
                arguments: ["install", "whisper-cpp"],
                onLog: onLog
            )
            return true
        } catch {
            onLog("  ✗ Falha ao instalar whisper-cpp: \(error.localizedDescription)")
            onLog("    Tente manualmente: brew install whisper-cpp")
            return false
        }
    }

    // MARK: - Model Download

    /// Returns the Homebrew default model directory path for the `small` model.
    private func defaultModelPath() -> String {
        // Homebrew on Apple Silicon
        let arm = "/opt/homebrew/share/whisper.cpp/models/ggml-small.bin"
        if FileManager.default.fileExists(atPath: arm) { return arm }

        // Homebrew on Intel
        let intel = "/usr/local/share/whisper.cpp/models/ggml-small.bin"
        if FileManager.default.fileExists(atPath: intel) { return intel }

        // Fallback — Homebrew will place it here after download-ggml-model.sh
        return arm
    }

    private func downloadModel(onLog: @escaping (String) -> Void) async -> Bool {
        // whisper-cpp installs a helper script `download-ggml-model` via Homebrew
        let scriptCandidates = [
            "/opt/homebrew/bin/download-ggml-model",
            "/usr/local/bin/download-ggml-model",
        ]

        guard let script = scriptCandidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            // Fallback: use the raw GitHub script
            onLog("  ⚠ Script de download não encontrado — tentando via curl...")
            return await downloadModelViaScript(onLog: onLog)
        }

        do {
            try await runProcess(
                executable: "/bin/sh",
                arguments: [script, "small"],
                onLog: onLog
            )
            return true
        } catch {
            onLog("  ✗ Falha ao baixar modelo: \(error.localizedDescription)")
            return false
        }
    }

    /// Last-resort fallback: pipe the official download script from GitHub directly.
    private func downloadModelViaScript(onLog: @escaping (String) -> Void) async -> Bool {
        let modelsDir: String
        if FileManager.default.fileExists(atPath: "/opt/homebrew") {
            modelsDir = "/opt/homebrew/share/whisper.cpp/models"
        } else {
            modelsDir = "/usr/local/share/whisper.cpp/models"
        }

        try? FileManager.default.createDirectory(
            atPath: modelsDir,
            withIntermediateDirectories: true
        )

        let scriptURL = "https://raw.githubusercontent.com/ggml-org/whisper.cpp/master/models/download-ggml-model.sh"
        let cmd = "curl -fsSL \(scriptURL) | bash -s small \(modelsDir)"

        do {
            try await runProcess(
                executable: "/bin/sh",
                arguments: ["-c", cmd],
                onLog: onLog
            )
            return true
        } catch {
            onLog("  ✗ Falha ao baixar modelo via script: \(error.localizedDescription)")
            onLog("    Baixe manualmente: https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin")
            return false
        }
    }

    // MARK: - Process Runner

    private func runProcess(
        executable: String,
        arguments: [String],
        onLog: @escaping (String) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError  = stderrPipe

            // Stream stdout lines in real time
            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                    let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
                    for line in lines {
                        Task { @MainActor in onLog("    \(line)") }
                    }
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }

            process.terminationHandler = { proc in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let errText = String(data: errData, encoding: .utf8) ?? "Exit \(proc.terminationStatus)"
                    continuation.resume(throwing: NSError(
                        domain: "WhisperInstaller",
                        code: Int(proc.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: errText]
                    ))
                }
            }
        }
    }
}
