import SwiftUI

struct CopierSourceView: View {
    @ObservedObject var vm: VaultCopierViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Vault de Origem")
                    .font(.title2.bold())
                Text("Selecione o vault de onde deseja copiar as configurações e plugins.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 20)

            if vm.availableVaults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Nenhum vault detectado")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(vm.availableVaults) { vault in
                            VaultRadioRowView(
                                vault: vault,
                                isSelected: vm.sourceVault?.id == vault.id,
                                isDisabled: false
                            ) {
                                vm.sourceVault = vault
                            }
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
        .padding(28)
        .task {
            if vm.availableVaults.isEmpty {
                vm.detectVaults()
            }
        }
    }
}

struct VaultRadioRowView: View {
    let vault: ObsidianVault
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                        .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(vault.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isDisabled ? .secondary : .primary)
                    Text(vault.path)
                        .font(.system(size: 10))
                        .foregroundStyle(isDisabled ? .tertiary : .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()

                Image(systemName: "archivebox.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Color.accentColor : Color(nsColor: .tertiaryLabelColor))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
