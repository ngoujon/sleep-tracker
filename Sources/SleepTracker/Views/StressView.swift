import SwiftUI
import SleepTrackerCore
import Charts

struct StressView: View {
    @EnvironmentObject var appState: AppState

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.locale = Locale(identifier: "fr_FR")
        return f
    }()

    private var available: [(day: HeartRateDay, score: StressScore)] {
        appState.stressScores.sorted { $0.day.date < $1.day.date }
    }

    var body: some View {
        ScrollView {
            if let (day, score) = appState.selectedStress {
                VStack(alignment: .leading, spacing: 24) {
                    header(day: day)

                    HStack(alignment: .top, spacing: 32) {
                        ScoreRingView(score: score.level, label: score.label, colorForScore: ScoreRingView.higherIsWorse)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sur les \(score.baselineDaysUsed) derniers jours")
                                .font(.headline)
                            Text("Le niveau de stress compare la VFC (variabilité de fréquence cardiaque) et la fréquence cardiaque au repos du jour à ta propre ligne de base glissante — pas à une norme générale, car ces valeurs varient énormément d'une personne à l'autre.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if !score.caveats.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(score.caveats, id: \.self) { c in
                                Label(c, systemImage: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Divider()

                    Text("Détail du niveau de stress")
                        .font(.headline)

                    VStack(spacing: 10) {
                        ForEach(score.components) { component in
                            ComponentRow(component: component, invertColor: true)
                        }
                    }

                    if available.count >= 2 {
                        Divider()
                        Text("Tendance")
                            .font(.headline)
                        Chart(available, id: \.day.id) { item in
                            LineMark(
                                x: .value("Jour", item.day.date),
                                y: .value("Stress", item.score.level)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(.orange)
                            PointMark(
                                x: .value("Jour", item.day.date),
                                y: .value("Stress", item.score.level)
                            )
                            .foregroundStyle(.orange)
                        }
                        .chartYScale(domain: 0...100)
                        .frame(height: 160)
                    }
                }
                .padding(24)
            } else if appState.heartRateDays.isEmpty {
                emptyState(text: "Aucune donnée de fréquence cardiaque importée.")
            } else if appState.stressScores.isEmpty {
                emptyState(text: "Pas encore assez d'historique pour calculer un niveau de stress : il faut au moins 5 jours de VFC ou de fréquence cardiaque au repos pour établir ta ligne de base personnelle.")
            } else {
                emptyState(text: "Pas assez d'historique avant cette date pour calculer un niveau de stress. Choisis un jour plus récent dans la liste.")
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    appState.presentImportPanel()
                } label: {
                    Label("Importer", systemImage: "square.and.arrow.down")
                }
            }
        }
    }

    @ViewBuilder
    private func emptyState(text: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text(text)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    @ViewBuilder
    private func header(day: HeartRateDay) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dateFormatter.string(from: day.date))
                    .font(.title2).bold()
                Text("Niveau de stress estimé")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if available.count > 1 {
                Picker("Jour", selection: dateSelectionBinding) {
                    ForEach(available.reversed(), id: \.day.date) { item in
                        Text(item.day.date.formatted(date: .abbreviated, time: .omitted)).tag(item.day.date as Date?)
                    }
                }
                .frame(width: 180)
            }
        }
    }

    private var dateSelectionBinding: Binding<Date?> {
        Binding(
            get: { appState.selectedHeartDate },
            set: { appState.selectedHeartDate = $0 }
        )
    }
}
