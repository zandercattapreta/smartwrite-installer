import SwiftUI

struct StepperBarView: View {
    let currentStep: InstallerViewModel.InstallStep

    var body: some View {
        HStack(spacing: 0) {
            ForEach(InstallerViewModel.InstallStep.allCases, id: \.self) { step in
                stepItem(step: step)
                if step != InstallerViewModel.InstallStep.allCases.last {
                    connectorLine(for: step)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
    }

    private func stepItem(step: InstallerViewModel.InstallStep) -> some View {
        let isDone = step.rawValue < currentStep.rawValue
        let isActive = step == currentStep

        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isDone ? Color.accentColor : (isActive ? Color.accentColor : Color(nsColor: .quaternaryLabelColor)))
                    .frame(width: 32, height: 32)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(step.rawValue + 1)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isActive ? .white : Color(nsColor: .secondaryLabelColor))
                }
            }
            Text(step.title)
                .font(.system(size: 10, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? Color.accentColor : Color(nsColor: .secondaryLabelColor))
                .fixedSize()
        }
        .animation(.easeInOut(duration: 0.25), value: currentStep)
    }

    private func connectorLine(for step: InstallerViewModel.InstallStep) -> some View {
        let isDone = step.rawValue < currentStep.rawValue
        return Rectangle()
            .fill(isDone ? Color.accentColor : Color(nsColor: .separatorColor))
            .frame(height: 2)
            .padding(.bottom, 22)
            .animation(.easeInOut(duration: 0.25), value: currentStep)
    }
}
