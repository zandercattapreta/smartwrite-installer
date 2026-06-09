// ==============================================================================
// SCRIPT: SmartWriteInstallerApp.swift
// DESCRIÇÃO: Entry point do aplicativo macOS SmartWrite Installer. Configura
//            a janela principal (sem barra de título, tamanho fixo ao conteúdo)
//            e registra o comando de menu "Sobre o SmartWrite Installer".
// CHAMADO POR: @main — ponto de entrada do processo pelo sistema operacional
// TRAZ (CHAMA/IMPORTA): SwiftUI, AppKit (NSApplication, NSWindow, NSHostingController)
// CONTRATO (RESPOSTA ESPERADA): Inicializa a cena SwiftUI com ContentView e
//            expõe a janela "Sobre" via menu de aplicativo personalizado.
// ==============================================================================

import SwiftUI

@main
struct SmartWriteInstallerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Sobre o SmartWrite Installer") {
                    showAboutWindow()
                }
            }
        }
    }
    
    func showAboutWindow() {
        let currentAboutWindows = NSApplication.shared.windows.filter { $0.title == "Sobre" }
        if let existing = currentAboutWindows.first {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        
        let aboutView = AboutView()
        let hostingController = NSHostingController(rootView: aboutView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Sobre"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentView = hostingController.view
        window.makeKeyAndOrderFront(nil)
    }
}
