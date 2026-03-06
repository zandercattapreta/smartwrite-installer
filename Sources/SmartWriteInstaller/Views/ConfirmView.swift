import SwiftUI

struct ConfirmView: View {
    @ObservedObject var vm: InstallerViewModel

    private var selectedPlugins: [Plugin] {
        vm.discoveredPlugins.filter { vm.selectedPlugins.contains($0.id) }
    }

    private var selectedVaults: [ObsidianVault] {
        vm.availableVaults.filter { vm.selectedVaults.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Confirmar Instalação")
                    .font(.title2.bold())
                Text("Revise suas seleções antes de instalar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 24)

            HStack(alignment: .top, spacing: 20) {
                // Plugins column
                VStack(alignment: .leading, spacing: 10) {
                    Label("\(selectedPlugins.count) plugin(s)", systemImage: "puzzlepiece.extension.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(selectedPlugins) { plugin in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 14))
                            Text(plugin.name)
                                .font(.system(size: 13))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )

                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(.secondary)
                    .padding(.top, 36)

                // Vaults column
                VStack(alignment: .leading, spacing: 10) {
                    Label("\(selectedVaults.count) vault(s)", systemImage: "archivebox.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(selectedVaults) { vault in
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(Color.accentColor)
                                .font(.system(size: 14))
                            Text(vault.name)
                                .font(.system(size: 13))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }

            Spacer()

            // Info box
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text("O instalador usará **git clone** para novos plugins e **git pull** para atualizações.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.08))
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
            .padding(.top, 20)
        }
        .padding(28)
    }
}
