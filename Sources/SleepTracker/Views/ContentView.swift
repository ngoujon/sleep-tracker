import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            if let candidate = appState.detectedCandidate, !appState.isImporting {
                CandidateBanner(candidate: candidate)
            }

            Group {
                if appState.sessions.isEmpty && appState.heartRateDays.isEmpty && !appState.isImporting {
                    EmptyStateView()
                } else if appState.isImporting {
                    ImportingView()
                } else {
                    TabView {
                        TonightView()
                            .tabItem { Label("Cette nuit", systemImage: "moon.stars.fill") }
                        StressView()
                            .tabItem { Label("Stress", systemImage: "waveform.path.ecg") }
                        HeartRateView()
                            .tabItem { Label("Fréquence cardiaque", systemImage: "heart.fill") }
                        HistoryView()
                            .tabItem { Label("Historique sommeil", systemImage: "chart.bar.fill") }
                        SettingsView()
                            .tabItem { Label("Réglages", systemImage: "gearshape.fill") }
                    }
                }
            }
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8])))
                    .overlay(Label("Dépose export.xml ou export.zip", systemImage: "square.and.arrow.down").font(.title3).bold())
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .alert("Erreur d'import", isPresented: .constant(appState.lastError != nil), actions: {
            Button("OK") { appState.lastError = nil }
        }, message: {
            Text(appState.lastError ?? "")
        })
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            let ext = url.pathExtension.lowercased()
            guard ext == "xml" || ext == "zip" else { return }
            DispatchQueue.main.async {
                appState.importFile(at: url)
            }
        }
        return true
    }
}

private struct CandidateBanner: View {
    @EnvironmentObject var appState: AppState
    let candidate: AutoImportScanner.Candidate

    private var relativeTime: String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.unitsStyle = .short
        return f.localizedString(for: candidate.modifiedAt, relativeTo: Date())
    }

    var body: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(.yellow)
            Text("Export Santé détecté : **\(candidate.url.lastPathComponent)** (\(relativeTime)).")
                .font(.subheadline)
            Spacer()
            Button("Ignorer") { appState.dismissDetectedCandidate() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            Button("Importer") { appState.importDetectedCandidate() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.12))
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
            Text("Exporte tes données depuis l'app Santé de l'iPhone (profil → Exporter toutes les données), puis AirDrop ou copie le fichier vers ce Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("Sommeil repère automatiquement export.zip/export.xml dans Téléchargements ou le Bureau — sinon glisse le fichier ici, ou choisis-le à la main.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
                appState.presentImportPanel()
            } label: {
                Label("Choisir le fichier manuellement", systemImage: "square.and.arrow.down")
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
