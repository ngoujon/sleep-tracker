import SwiftUI
import SleepTrackerCore
import Charts

struct HistoryView: View {
    @EnvironmentObject var appState: AppState

    private var data: [(session: SleepSession, score: SleepScore)] {
        appState.scoredSessions.sorted { $0.session.nightOf < $1.session.nightOf }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Historique").font(.title2).bold().padding([.top, .horizontal])

            if data.count >= 2 {
                Chart(data, id: \.session.id) { item in
                    LineMark(
                        x: .value("Nuit", item.session.nightOf),
                        y: .value("Score", item.score.total)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.indigo)

                    PointMark(
                        x: .value("Nuit", item.session.nightOf),
                        y: .value("Score", item.score.total)
                    )
                    .foregroundStyle(.indigo)
                }
                .chartYScale(domain: 0...100)
                .frame(height: 220)
                .padding(.horizontal)
            }

            List {
                ForEach(data.reversed(), id: \.session.id) { item in
                    Button {
                        appState.selectedNightOf = item.session.nightOf
                    } label: {
                        HStack {
                            Text(item.session.nightOf.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Text(formatHours(item.session.asleepMinutes))
                                .foregroundStyle(.secondary)
                            Text("\(item.score.total)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(colorFor(item.score.total))
                                .frame(width: 36)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func formatHours(_ minutes: Double) -> String {
        let h = Int(minutes / 60)
        let m = Int(minutes.truncatingRemainder(dividingBy: 60))
        return "\(h) h \(String(format: "%02d", m))"
    }

    private func colorFor(_ score: Int) -> Color {
        switch score {
        case 90...: return .green
        case 70..<90: return .mint
        case 55..<70: return .yellow
        case 40..<55: return .orange
        default: return .red
        }
    }
}
