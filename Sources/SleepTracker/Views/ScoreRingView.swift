import SwiftUI

struct ScoreRingView: View {
    let score: Int
    let label: String
    /// Defaults to "higher is better" (sleep score). Pass a custom mapping
    /// for values where higher means worse (e.g. a stress level).
    var colorForScore: (Int) -> Color = ScoreRingView.higherIsBetter

    private var color: Color { colorForScore(score) }

    static func higherIsBetter(_ score: Int) -> Color {
        switch score {
        case 90...: return .green
        case 70..<90: return .mint
        case 55..<70: return .yellow
        case 40..<55: return .orange
        default: return .red
        }
    }

    static func higherIsWorse(_ score: Int) -> Color {
        switch score {
        case ..<25: return .green
        case 25..<50: return .yellow
        case 50..<75: return .orange
        default: return .red
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 16)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: score)
            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 160, height: 160)
    }
}
