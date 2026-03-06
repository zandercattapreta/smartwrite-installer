import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) var openURL
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 20)
            
            VStack(spacing: 4) {
                Text("SmartWrite Installer")
                    .font(.title2.bold())
                
                Text("Versão \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text("Utilitário oficial para gerenciamento, instalação e atualização de plugins e configurações SmartWrite em vaults do Obsidian.")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(spacing: 12) {
                Text("Tecnologias Utilizadas")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 24) {
                    TechBadge(name: "SwiftUI", icon: "swift")
                    TechBadge(name: "Git CLI", icon: "externaldrive.fill")
                    TechBadge(name: "NPM Build", icon: "shippingbox.fill")
                }
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
            .cornerRadius(12)
            .padding(.horizontal, 40)
            
            VStack(spacing: 4) {
                Text("© 2026 Z•Edições")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button(action: {
                    openURL(URL(string: "https://github.com/zandercpzed/smartwrite-installer")!)
                }) {
                    Text("Código Fonte (GitHub)")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
            .padding(.bottom, 20)
        }
        .frame(width: 400, height: 420)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct TechBadge: View {
    let name: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
            Text(name)
                .font(.system(size: 10, weight: .medium))
        }
    }
}
