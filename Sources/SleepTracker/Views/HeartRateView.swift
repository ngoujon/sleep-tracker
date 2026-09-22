import SwiftUI
import SleepTrackerCore
import Charts

struct HeartRateView: View {
    @EnvironmentObject var appState: AppState

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.locale = Locale(identifier: "fr_FR")
        return f
    }()

    private var days: [HeartRateDay] { appState.heartRateDays }

    var body: some View {
        ScrollView {
            if let day = appState.selectedHeartRateDay {
                VStack(alignment: .leading, spacing: 24) {
                    header(day: day)

                    HStack(spacing: 16) {
                        statTile(title: "Repos", value: day.restingBPM, unit: "bpm", color: .pink)
                        statTile(title: "Minimum", value: day.minBPM, unit: "bpm", color: .blue)
                        statTile(title: "Moyenne", value: day.avgBPM, unit: "bpm", color: .indigo)
                        statTile(title: "Maximum", value: day.maxBPM, unit: "bpm", color: .red)
                    }

                    if let hrv = day.hrvSDNN {
                        statTile(title: "Variabilité (HRV, SDNN)", value: hrv, unit: "ms", color: .teal, wide: true)
                    }
                    if let resp = day.respiratoryRate {
                        statTile(title: "Fréquence respiratoire", value: resp, unit: "resp/min", color: .cyan, wide: true)
                    }

                    if days.count >= 2 {
                        Divider()
                        Text("Fréquence cardiaque au repos — tendance")
                            .font(.headline)
                        Chart(days, id: \.id) { d in
                            if let resting = d.restingBPM {
                                LineMark(
                                    x: .value("Jour", d.date),
                                    y: .value("Repos", resting)
                                )
                                .interpolationMethod(.monotone)
                                .foregroundStyle(.pink)
                            }
                        }
                        .frame(height: 160)

                        Text("Fréquence cardiaque moyenne — tendance")
                            .font(.headline)
                        Chart(days, id: \.id) { d in
                            if let avg = d.avgBPM {
                                LineMark(
                                    x: .value("Jour", d.date),
                                    y: .value("Moyenne", avg)
                                )
                                .interpolationMethod(.monotone)
                                .foregroundStyle(.indigo)
                            }
                        }
                        .frame(height: 160)
                    }
                }
                .padding(24)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 48))
                        .foregroundStyle(.pink)
                    Text("Aucune donnée de fréquence cardiaque importée.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    private func statTile(title: String, value: Double?, unit: String, color: Color, wide: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let value {
                Text("\(Int(value.rounded())) \(unit)")
                    .font(.title2).bold()
                    .foregroundStyle(color)
            } else {
                Text("—")
                    .font(.title2).bold()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: wide ? .infinity : nil, alignment: .leading)
        .frame(minWidth: wide ? nil : 90)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.1)))
    }

    @ViewBuilder
    private func header(day: HeartRateDay) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dateFormatter.string(from: day.date))
                    .font(.title2).bold()
                Text("Fréquence cardiaque")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if days.count > 1 {
                Picker("Jour", selection: dateSelectionBinding) {
                    ForEach(days.reversed(), id: \.date) { d in
                        Text(d.date.formatted(date: .abbreviated, time: .omitted)).tag(d.date as Date?)
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
