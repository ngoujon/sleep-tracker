import SwiftUI
import SleepTrackerCore

struct PhaseBreakdownView: View {
    let session: SleepSession

    private var segments: [(name: String, minutes: Double, color: Color)] {
        if session.hasStageDetail {
            return [
                ("Profond", session.deepMinutes, .indigo),
                ("Léger", session.coreMinutes, .blue),
                ("REM", session.remMinutes, .purple),
                ("Éveil", session.awakeMinutes, .orange.opacity(0.7))
            ]
        } else {
            return [
                ("Sommeil", session.asleepMinutes, .blue),
                ("Éveil", session.awakeMinutes, .orange.opacity(0.7))
            ]
        }
    }

    private var total: Double { max(segments.reduce(0) { $0 + $1.minutes }, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(segments, id: \.name) { seg in
                        if seg.minutes > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(seg.color)
                                .frame(width: max(geo.size.width * seg.minutes / total, 2))
                        }
                    }
                }
            }
            .frame(height: 28)

            HStack(spacing: 16) {
                ForEach(segments, id: \.name) { seg in
                    if seg.minutes > 0 {
                        HStack(spacing: 6) {
                            Circle().fill(seg.color).frame(width: 8, height: 8)
                            Text("\(seg.name) · \(formatMinutes(seg.minutes))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let h = Int(minutes / 60)
        let m = Int(minutes.truncatingRemainder(dividingBy: 60))
        return h > 0 ? "\(h) h \(String(format: "%02d", m))" : "\(m) min"
    }
}
