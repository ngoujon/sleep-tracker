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
                LabeledContent("Jours de fréquence cardiaque", value: "\(appState.heartRateDays.count)")
                Button("Réimporter les données Santé…") {
                    appState.presentImportPanel()
                }
            }

            Section("Méthode de calcul du score de sommeil") {
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

            Section("Méthode de calcul du niveau de stress") {
                Text("""
                Le niveau de stress (0-100, plus haut = plus de stress) est lui aussi un calcul déterministe, sans IA. Il compare chaque jour à ta propre ligne de base glissante (moyenne + écart-type sur les 30 jours précédents, minimum 5 jours de données) :
                • Variabilité cardiaque, HRV/SDNN (60 pts) — un HRV en dessous de ta ligne de base indique un stress physiologique plus élevé
                • Fréquence cardiaque au repos (40 pts) — une fréquence au repos au-dessus de ta ligne de base va dans le même sens
                Une ligne de base personnelle est utilisée plutôt qu'un seuil universel car le HRV varie énormément d'une personne à l'autre (Task Force ESC/NASPE 1996). Le lien entre HRV réduit et stress est établi par la méta-analyse de Kim et al., "Stress and Heart Rate Variability", Psychiatry Investigation, 2018.
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
