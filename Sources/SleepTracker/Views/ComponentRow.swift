import SwiftUI
import SleepTrackerCore

struct ComponentRow: View {
    let component: ComponentScore
    /// When true, a *high* fraction is bad (e.g. a stress contribution)
    /// instead of good (e.g. a sleep-score component), flipping the bar color.
    var invertColor: Bool = false

    private var fraction: Double { component.maxPoints > 0 ? component.points / component.maxPoints : 0 }

    private var barColor: Color {
        let goodFraction = invertColor ? 1 - fraction : fraction
        return goodFraction > 0.75 ? .green : (goodFraction > 0.4 ? .yellow : .red)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(component.name).font(.subheadline).bold()
                Spacer()
                Text("\(String(format: "%.1f", component.points)) / \(Int(component.maxPoints)) pts")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)
            Text(component.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
    }
}
