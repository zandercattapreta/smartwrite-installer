import SwiftUI

struct VaultCopierTabView: View {
    @ObservedObject var vm: VaultCopierViewModel

    var body: some View {
        VStack(spacing: 0) {
            // App header
            HStack(spacing: 12) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("SmartWrite Copier")
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

            CopierStepperBarView(currentStep: vm.currentStep)

            Divider()

            // Step content
            Group {
                switch vm.currentStep {
                case .selectSource:
                    CopierSourceView(vm: vm)
                case .selectTarget:
                    CopierTargetView(vm: vm)
                case .selectOptions:
                    CopierOptionsView(vm: vm)
                case .copying:
                    CopierProgressView(vm: vm)
                }
            }
            .frame(minHeight: 340)

            Divider()

            // Bottom navigation bar
            HStack {
                if vm.currentStep != .selectSource && vm.currentStep != .copying {
                    Button("← Voltar") {
                        vm.previousStep()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if vm.currentStep == .selectOptions {
                    Button("🚀  Copiar Agora") {
                        Task { await vm.startCopy() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(!vm.canContinue())
                } else if vm.currentStep == .copying {
                    if case .completed = vm.copyStatus {
                        Button("Voltar ao Início") {
                            vm.currentStep = .selectSource
                            vm.sourceVault = nil
                            vm.targetVaults.removeAll()
                            vm.copyStatus = .idle
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

struct CopierStepperBarView: View {
    let currentStep: VaultCopierViewModel.CopierStep
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(VaultCopierViewModel.CopierStep.allCases, id: \.self) { step in
                let isActive = step == currentStep
                let isPast = step.rawValue < currentStep.rawValue
                
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(isActive ? Color.accentColor : (isPast ? Color.accentColor.opacity(0.3) : Color(nsColor: .controlColor)))
                            .frame(width: 28, height: 28)
                        
                        if isPast {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                        } else {
                            Text("\(step.rawValue + 1)")
                                .font(.system(size: 13, weight: isActive ? .bold : .medium))
                                .foregroundStyle(isActive ? .white : .secondary)
                        }
                    }
                    
                    Text(step.title)
                        .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
                
                if step != VaultCopierViewModel.CopierStep.allCases.last {
                    Rectangle()
                        .fill(isPast ? Color.accentColor.opacity(0.3) : Color(nsColor: .separatorColor))
                        .frame(height: 2)
                        .padding(.horizontal, -20)
                        .offset(y: -10)
                        .zIndex(-1)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
