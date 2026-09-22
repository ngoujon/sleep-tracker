import SwiftUI

struct ScoreRingView: View {
    let score: Int
    let label: String

    private var color: Color {
        switch score {
        case 90...: return .green
        case 70..<90: return .mint
        case 55..<70: return .yellow
        case 40..<55: return .orange
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
