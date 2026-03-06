import SwiftUI

struct CopierProgressView: View {
    @ObservedObject var vm: VaultCopierViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Progresso da Cópia")
                .font(.title2.bold())

            // Status e Progresso Bar
            VStack(alignment: .leading, spacing: 8) {
                switch vm.copyStatus {
                case .idle:
                    Text("Preparando...")
                        .foregroundStyle(.secondary)
                    ProgressView(value: 0, total: 100)

                case .copying(let current, let total, let message):
                    HStack {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(current) de \(total)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(current), total: Double(total))
                        .tint(.accentColor)

                case .completed(let success, let failed):
                    HStack {
                        Image(systemName: failed == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(failed == 0 ? .green : .orange)
                        Text(failed == 0 ? "Cópia concluída com sucesso!" : "Cópia concluída com \(failed) erros.")
                            .font(.headline)
                    }
                    ProgressView(value: 100, total: 100)
                        .tint(failed == 0 ? .green : .orange)

                case .failed(let error):
                    HStack {
                        Image(systemName: "xmark.octagon.fill")
                            .foregroundStyle(.red)
                        Text("Falha na cópia")
                            .font(.headline)
                    }
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                    ProgressView(value: 0, total: 100)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Log de execução
            VStack(alignment: .leading, spacing: 4) {
                Text("Log")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(vm.copyLog.enumerated()), id: \.offset) { index, log in
                                Text(log)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(log.contains("Erro") || log.contains("✗") ? Color.red : Color.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(index)
                            }
                        }
                        .padding(8)
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .onChange(of: vm.copyLog.count) { _ in
                        if !vm.copyLog.isEmpty {
                            withAnimation {
                                proxy.scrollTo(vm.copyLog.count - 1, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .padding(28)
    }
}
