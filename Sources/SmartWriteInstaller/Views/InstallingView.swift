import SwiftUI

struct InstallingView: View {
    @ObservedObject var vm: InstallerViewModel
    @State private var scrollProxy: ScrollViewProxy? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status header
            HStack(spacing: 14) {
                statusIcon
                VStack(alignment: .leading, spacing: 3) {
                    Text(statusTitle)
                        .font(.title2.bold())
                    Text(statusSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if case .installing(let current, let total, _) = vm.installationStatus {
                    Text("\(current)/\(total)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 16)

            // Progress bar
            if case .installing(let current, let total, _) = vm.installationStatus {
                let progress = total > 0 ? Double(current) / Double(total) : 0
                ProgressView(value: progress)
                    .tint(Color.accentColor)
                    .padding(.bottom, 16)
            } else if case .completed = vm.installationStatus {
                ProgressView(value: 1.0)
                    .tint(.green)
                    .padding(.bottom, 16)
            }

            // Log scroll view
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(vm.installationLog.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(logColor(for: line))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                    .padding(12)
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .textBackgroundColor))
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .frame(maxHeight: 220)
                .onChange(of: vm.installationLog.count) {
                    if let lastIndex = vm.installationLog.indices.last {
                        withAnimation {
                            proxy.scrollTo(lastIndex, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .padding(28)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch vm.installationStatus {
        case .installing:
            ProgressView()
                .scaleEffect(1.2)
                .frame(width: 32, height: 32)
        case .completed(_, let failed):
            Image(systemName: failed > 0 ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(failed > 0 ? .orange : .green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.red)
        default:
            EmptyView()
        }
    }

    private var statusTitle: String {
        switch vm.installationStatus {
        case .installing(_, _, let msg): return msg
        case .completed(_, let f): return f > 0 ? "Concluído com erros" : "Instalação completa!"
        case .failed(let msg): return "Falhou: \(msg)"
        default: return "Iniciando..."
        }
    }

    private var statusSubtitle: String {
        switch vm.installationStatus {
        case .installing: return "Por favor, aguarde..."
        case .completed(let s, let f): return "\(s) sucesso(s)\(f > 0 ? ", \(f) falha(s)" : ""). Reinicie o Obsidian."
        case .failed: return "Verifique o log abaixo."
        default: return ""
        }
    }

    private func logColor(for line: String) -> Color {
        if line.hasPrefix("✓") || line.hasPrefix("🎉") { return .green }
        if line.hasPrefix("✗") { return .red }
        if line.hasPrefix("⚠") { return .orange }
        if line.hasPrefix("🔍") || line.hasPrefix("📂") || line.hasPrefix("🚀") { return Color.accentColor }
        return Color(nsColor: .labelColor).opacity(0.8)
    }
}
