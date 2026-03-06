import SwiftUI

struct CopierTargetView: View {
    @ObservedObject var vm: VaultCopierViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Vault de Destino")
                    .font(.title2.bold())
                Text("Selecione o vault que REGISTRARÁ as configurações copiadas.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(vm.availableVaults) { vault in
                        let isSource = vm.sourceVault?.id == vault.id
                        VaultRowView(
                            vault: vault,
                            isSelected: vm.targetVaults.contains(vault.id),
                            onToggle: {
                                if vm.targetVaults.contains(vault.id) {
                                    vm.targetVaults.remove(vault.id)
                                } else {
                                    vm.targetVaults.insert(vault.id)
                                }
                            }
                        )
                        .opacity(isSource ? 0.4 : 1.0)
                        .disabled(isSource)
                    }
                }
            }
            .frame(maxHeight: 260)
            
            if !vm.targetVaults.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Os itens selecionados no vault de destino serão sobrescritos. Faça backup antes se necessário.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.top, 16)
            }
        }
        .padding(28)
    }
}
