import SwiftUI
import SleepTrackerCore

struct TonightView: View {
    @EnvironmentObject var appState: AppState

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.locale = Locale(identifier: "fr_FR")
        return f
    }()

    var body: some View {
        ScrollView {
            if let (session, score) = appState.latest {
                VStack(alignment: .leading, spacing: 24) {
                    header(session: session)

                    HStack(alignment: .top, spacing: 32) {
                        ScoreRingView(score: score.total, label: score.label)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Répartition des phases")
                                .font(.headline)
                            PhaseBreakdownView(session: session)
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

                    Text("Détail du score")
                        .font(.headline)

                    VStack(spacing: 10) {
                        ForEach(score.components) { component in
                            ComponentRow(component: component)
                        }
                    }
                }
                .padding(24)
            } else {
                Text("Sélectionne une nuit dans l'historique.")
                    .foregroundStyle(.secondary)
                    .padding()
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
    private func header(session: SleepSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dateFormatter.string(from: session.nightOf))
                    .font(.title2).bold()
                Text("Coucher \(session.start.formatted(date: .omitted, time: .shortened)) → lever \(session.end.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if appState.sessions.count > 1 {
                Picker("Nuit", selection: nightSelectionBinding) {
                    ForEach(appState.sessions.reversed(), id: \.nightOf) { s in
                        Text(s.nightOf.formatted(date: .abbreviated, time: .omitted)).tag(s.nightOf as Date?)
                    }
                }
                .frame(width: 180)
            }
        }
    }

    private var nightSelectionBinding: Binding<Date?> {
        Binding(
            get: { appState.selectedNightOf },
            set: { appState.selectedNightOf = $0 }
        )
    }
}

private struct ComponentRow: View {
    let component: ComponentScore

    private var fraction: Double { component.maxPoints > 0 ? component.points / component.maxPoints : 0 }

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
                        .fill(fraction > 0.75 ? Color.green : (fraction > 0.4 ? Color.yellow : Color.red))
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
