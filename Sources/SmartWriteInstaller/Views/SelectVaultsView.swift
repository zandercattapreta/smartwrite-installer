import SwiftUI

struct SelectVaultsView: View {
    @ObservedObject var vm: InstallerViewModel
    @State private var manualPath = ""
    @State private var showManualEntry = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Vaults do Obsidian")
                    .font(.title2.bold())
                Text("Selecione em quais vaults instalar os plugins.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 20)

            if vm.availableVaults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Nenhum vault detectado automaticamente")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Certifique-se de que o Obsidian foi aberto ao menos uma vez.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(vm.availableVaults) { vault in
                            VaultRowView(vault: vault, isSelected: vm.selectedVaults.contains(vault.id)) {
                                if vm.selectedVaults.contains(vault.id) {
                                    vm.selectedVaults.remove(vault.id)
                                } else {
                                    vm.selectedVaults.insert(vault.id)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 260)
            }

            Divider().padding(.vertical, 16)

            DisclosureGroup(isExpanded: $showManualEntry) {
                HStack(spacing: 10) {
                    TextField("/Users/voce/Documents/MeuVault", text: $manualPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Adicionar") {
                        vm.addManualVault(path: manualPath)
                        manualPath = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(manualPath.isEmpty)
                }
                .padding(.top, 10)
            } label: {
                Label("Adicionar vault manualmente", systemImage: "folder.badge.plus")
                    .font(.subheadline.weight(.medium))
            }
        }
        .padding(28)
    }
}

struct VaultRowView: View {
    let vault: ObsidianVault
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                        .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(vault.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(vault.path)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
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
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
