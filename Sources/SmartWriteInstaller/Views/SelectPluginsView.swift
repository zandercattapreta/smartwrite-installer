import SwiftUI

struct SelectPluginsView: View {
    @ObservedObject var vm: InstallerViewModel
    @State private var isRefreshing = false
    @State private var showCustomField = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Plugins Disponíveis")
                        .font(.title2.bold())
                    Text("Selecione quais plugins SmartWrite instalar nos seus vaults.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task {
                        isRefreshing = true
                        await vm.discoverPlugins()
                        isRefreshing = false
                    }
                } label: {
                    Label("Atualizar", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .disabled(isRefreshing)
            }
            .padding(.bottom, 20)

            if case .discovering = vm.installationStatus {
                HStack(spacing: 12) {
                    ProgressView().scaleEffect(0.8)
                    Text("Buscando plugins no GitHub...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else if vm.discoveredPlugins.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Nenhum plugin encontrado")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Clique em Atualizar para buscar plugins no GitHub.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(vm.discoveredPlugins) { plugin in
                            PluginRowView(plugin: plugin, isSelected: vm.selectedPlugins.contains(plugin.id)) {
                                if vm.selectedPlugins.contains(plugin.id) {
                                    vm.selectedPlugins.remove(plugin.id)
                                } else {
                                    vm.selectedPlugins.insert(plugin.id)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 260)
            }

            Divider().padding(.vertical, 16)

            // Custom plugin section
            DisclosureGroup(isExpanded: $showCustomField) {
                HStack(spacing: 10) {
                    TextField("https://github.com/usuario/plugin", text: $vm.customRepoURL)
                        .textFieldStyle(.roundedBorder)
                    Button("Adicionar") {
                        Task { await vm.addCustomPlugin() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.customRepoURL.isEmpty)
                }
                .padding(.top, 10)
            } label: {
                Label("Plugin personalizado (URL do GitHub)", systemImage: "plus.circle")
                    .font(.subheadline.weight(.medium))
            }
        }
        .padding(28)
        .task {
            if vm.discoveredPlugins.isEmpty {
                await vm.discoverPlugins()
            }
            vm.detectVaults()
        }
    }
}

struct PluginRowView: View {
    let plugin: Plugin
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
                    Text(plugin.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(plugin.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()

                Image(systemName: "puzzlepiece.extension.fill")
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
