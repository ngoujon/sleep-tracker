import Foundation
import SleepTrackerCore
import Combine
import AppKit
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published var sessions: [SleepSession] = []
    @Published var ageBracket: AgeBracket
    @Published var isImporting = false
    @Published var importProgress: Int = 0
    @Published var lastError: String?
    @Published var lastImportSource: String?
    @Published var selectedNightOf: Date?

    init() {
        let settings = Store.shared.loadSettings()
        self.ageBracket = settings.ageBracket
        self.lastImportSource = settings.lastImportedSource
        self.sessions = Store.shared.loadSessions().sorted { $0.nightOf < $1.nightOf }
        self.selectedNightOf = self.sessions.last?.nightOf
    }

    var scoredSessions: [(session: SleepSession, score: SleepScore)] {
        sessions.map { ($0, SleepScoreEngine.score(for: $0, ageBracket: ageBracket)) }
    }

    var latest: (session: SleepSession, score: SleepScore)? {
        guard let nightOf = selectedNightOf, let session = sessions.first(where: { $0.nightOf == nightOf }) ?? sessions.last else { return nil }
        return (session, SleepScoreEngine.score(for: session, ageBracket: ageBracket))
    }

    func setAgeBracket(_ bracket: AgeBracket) {
        ageBracket = bracket
        var settings = Store.shared.loadSettings()
        settings.ageBracket = bracket
        Store.shared.saveSettings(settings)
    }

    func presentImportPanel() {
        let panel = NSOpenPanel()
        panel.title = "Importer les données Santé"
        panel.message = "Choisis export.xml ou export.zip (Santé → profil → Exporter toutes les données)."
        panel.allowedContentTypes = [.xml, .zip]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importFile(at: url)
    }

    func importFile(at url: URL) {
        isImporting = true
        importProgress = 0
        lastError = nil
        let isFirstImport = Store.shared.loadSettings().lastImportDate == nil
        Task.detached { [weak self] in
            do {
                let result = try ImportService.importHealthData(from: url) { count in
                    Task { @MainActor [weak self] in self?.importProgress = count }
                }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.sessions = result.sessions.sorted { $0.nightOf < $1.nightOf }
                    self.selectedNightOf = self.sessions.last?.nightOf
                    self.lastImportSource = result.sourceUsed
                    self.isImporting = false

                    // Auto-detect age bracket from the export's date-of-birth on the
                    // very first import only; never override an explicit user choice later.
                    if isFirstImport, let dob = result.dateOfBirth {
                        let years = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 30
                        self.setAgeBracket(AgeBracket.from(age: years))
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.isImporting = false
                    self?.lastError = error.localizedDescription
                }
            }
        }
    }
}
