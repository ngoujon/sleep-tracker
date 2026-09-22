import SwiftUI

@main
struct SleepTrackerApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 760, minHeight: 560)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Importer les données Santé…") {
                    appState.presentImportPanel()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
