import SwiftUI

struct ContentView: View {
    @StateObject private var vm = InstallerViewModel()
    @StateObject private var copierVm = VaultCopierViewModel()

    var body: some View {
        TabView {
            InstallerTabView(vm: vm)
                .tabItem {
                    Label("Instalar Plugins", systemImage: "puzzlepiece.extension")
                }
            
            VaultCopierTabView(vm: copierVm)
                .tabItem {
                    Label("Copiar Vault", systemImage: "doc.on.doc")
                }
        }
        .frame(width: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct InstallerTabView: View {
    @ObservedObject var vm: InstallerViewModel

    var body: some View {
        VStack(spacing: 0) {
            // App header
            HStack(spacing: 12) {
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("SmartWrite Installer")
                        .font(.system(size: 15, weight: .bold))
                    Text("by Z•Edições")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // Stepper bar
            StepperBarView(currentStep: vm.currentStep)

            Divider()

            // Step content
            Group {
                switch vm.currentStep {
                case .selectPlugins:
                    SelectPluginsView(vm: vm)
                case .selectVaults:
                    SelectVaultsView(vm: vm)
                case .confirm:
                    ConfirmView(vm: vm)
                case .installing:
                    InstallingView(vm: vm)
                }
            }
            .frame(minHeight: 340)

            Divider()

            // Bottom navigation bar
            HStack {
                if vm.currentStep != .selectPlugins && vm.currentStep != .installing {
                    Button("← Voltar") {
                        vm.previousStep()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if vm.currentStep == .confirm {
                    Button("🚀  Instalar Agora") {
                        Task { await vm.install() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: [])
                } else if vm.currentStep == .installing {
                    if case .completed = vm.installationStatus {
                        Button("Fechar") {
                            NSApplication.shared.terminate(nil)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    Button("Continuar →") {
                        vm.nextStep()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!vm.canContinue())
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
        }
    }
}
