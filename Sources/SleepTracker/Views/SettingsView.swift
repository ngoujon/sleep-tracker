import SwiftUI
import SleepTrackerCore

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Profil") {
                Picker("Tranche d'âge", selection: Binding(
                    get: { appState.ageBracket },
                    set: { appState.setAgeBracket($0) }
                )) {
                    ForEach(AgeBracket.allCases) { bracket in
                        Text(bracket.label).tag(bracket)
                    }
                }
                Text("Utilisée pour les seuils de durée, d'efficacité et de continuité du sommeil (National Sleep Foundation).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Données") {
                if let source = appState.lastImportSource, !source.isEmpty {
                    LabeledContent("Source utilisée", value: source)
                }
                LabeledContent("Nuits importées", value: "\(appState.sessions.count)")
                Button("Réimporter les données Santé…") {
                    appState.presentImportPanel()
                }
            }

            Section("Méthode de calcul du score") {
                Text("""
                Le score (0-100) est un calcul déterministe, recalculé de la même façon à chaque nuit — aucune IA n'intervient dans le calcul. Il pondère :
                • Durée de sommeil (30 pts) — National Sleep Foundation, Hirshkowitz et al. 2015
                • Efficacité du sommeil (20 pts)
                • Continuité : réveils nocturnes (20 pts)
                • Architecture du sommeil : profond + REM (30 pts)
                Ces seuils viennent du panel de consensus de la National Sleep Foundation (Ohayon et al., "National Sleep Foundation's sleep quality recommendations: first report", Sleep Health, 2017), qui a établi objectivement ce qui indique une bonne qualité de sommeil par tranche d'âge.
                Si une donnée (phases, réveils…) manque pour une nuit, la composante correspondante est simplement exclue et le score est recalculé sur les composantes disponibles.
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
