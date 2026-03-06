import SwiftUI

struct CopierOptionsView: View {
    @ObservedObject var vm: VaultCopierViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("O que copiar")
                    .font(.title2.bold())
                Text("Escolha os componentes que deseja sincronizar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: $vm.copyOptions.plugins) {
                    VStack(alignment: .leading) {
                        Text("Plugins")
                            .font(.headline)
                        Text("Copia toda a pasta .obsidian/plugins/")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle())

                Toggle(isOn: $vm.copyOptions.activePlugins) {
                    VStack(alignment: .leading) {
                        Text("Lista de Plugins Ativos")
                            .font(.headline)
                        Text("Copia community-plugins.json para manter habilitados os mesmos plugins.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle())

                Toggle(isOn: $vm.copyOptions.preferences) {
                    VStack(alignment: .leading) {
                        Text("Preferências Gerais")
                            .font(.headline)
                        Text("Copia app.json, appearance.json, hotkeys.json e core-plugins.json.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle())

                Toggle(isOn: $vm.copyOptions.snippets) {
                    VStack(alignment: .leading) {
                        Text("Snippets CSS")
                            .font(.headline)
                        Text("Copia a pasta .obsidian/snippets/ completa.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle())
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            
            Spacer()
        }
        .padding(28)
    }
}
