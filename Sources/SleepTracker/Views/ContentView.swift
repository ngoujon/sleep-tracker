import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.sessions.isEmpty && !appState.isImporting {
                EmptyStateView()
            } else if appState.isImporting {
                ImportingView()
            } else {
                TabView {
                    TonightView()
                        .tabItem { Label("Cette nuit", systemImage: "moon.stars.fill") }
                    HistoryView()
                        .tabItem { Label("Historique", systemImage: "chart.bar.fill") }
                    SettingsView()
                        .tabItem { Label("Réglages", systemImage: "gearshape.fill") }
                }
            }
        }
        .alert("Erreur d'import", isPresented: .constant(appState.lastError != nil), actions: {
            Button("OK") { appState.lastError = nil }
        }, message: {
            Text(appState.lastError ?? "")
        })
    }
}

private struct EmptyStateView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 64))
                .foregroundStyle(.indigo)
            Text("Aucune donnée de sommeil")
                .font(.title2).bold()
            Text("Exporte tes données depuis l'app Santé de l'iPhone\n(profil → Exporter toutes les données)\npuis importe le fichier export.xml ou export.zip ici.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
                appState.presentImportPanel()
            } label: {
                Label("Importer les données Santé", systemImage: "square.and.arrow.down")
                    .padding(.horizontal, 8).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ImportingView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Analyse des données de sommeil… (\(appState.importProgress) relevés)")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
