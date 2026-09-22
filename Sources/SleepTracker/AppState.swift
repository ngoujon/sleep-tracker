import Foundation
import SleepTrackerCore
import Combine
import AppKit
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published var sessions: [SleepSession] = []
    @Published var heartRateDays: [HeartRateDay] = []
    @Published var ageBracket: AgeBracket
    @Published var isImporting = false
    @Published var importProgress: Int = 0
    @Published var lastError: String?
    @Published var lastImportSource: String?
    @Published var selectedNightOf: Date?
    @Published var selectedHeartDate: Date?
    @Published var detectedCandidate: AutoImportScanner.Candidate?

    private var activationObserver: NSObjectProtocol?

    init() {
        let settings = Store.shared.loadSettings()
        self.ageBracket = settings.ageBracket
        self.lastImportSource = settings.lastImportedSource
        self.sessions = Store.shared.loadSessions().sorted { $0.nightOf < $1.nightOf }
        self.selectedNightOf = self.sessions.last?.nightOf
        self.heartRateDays = Store.shared.loadHeartRateDays().sorted { $0.date < $1.date }
        self.selectedHeartDate = Self.bestDefaultDate(in: self.heartRateDays)

        scanForCandidateExport()
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.scanForCandidateExport() }
        }
    }

    deinit {
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
    }

    /// Rescans Téléchargements/Bureau for a recent Health export (see
    /// `AutoImportScanner`). Called at launch and whenever the app regains
    /// focus, so a file AirDropped while Sommeil was already open gets picked
    /// up as soon as the user switches back to it.
    func scanForCandidateExport() {
        guard let found = AutoImportScanner.scan() else {
            detectedCandidate = nil
            return
        }
        let settings = Store.shared.loadSettings()
        if settings.dismissedCandidatePath == found.url.path, settings.dismissedCandidateModDate == found.modifiedAt {
            detectedCandidate = nil
            return
        }
        detectedCandidate = found
    }

    func dismissDetectedCandidate() {
        guard let detectedCandidate else { return }
        var settings = Store.shared.loadSettings()
        settings.dismissedCandidatePath = detectedCandidate.url.path
        settings.dismissedCandidateModDate = detectedCandidate.modifiedAt
        Store.shared.saveSettings(settings)
        self.detectedCandidate = nil
    }

    func importDetectedCandidate() {
        guard let detectedCandidate else { return }
        importFile(at: detectedCandidate.url)
        self.detectedCandidate = nil
    }

    /// The most recent day that actually carries a resting-HR or HRV reading,
    /// rather than just the chronologically-last day. A day made only of a
    /// couple of stray continuous heart-rate samples (e.g. from a day-boundary
    /// timezone edge case) shouldn't become the default selection, since it
    /// has nothing meaningful to show and no stress score can be computed for it.
    private static func bestDefaultDate(in days: [HeartRateDay]) -> Date? {
        days.last { $0.restingBPM != nil || $0.hrvSDNN != nil }?.date ?? days.last?.date
    }

    var scoredSessions: [(session: SleepSession, score: SleepScore)] {
        sessions.map { ($0, SleepScoreEngine.score(for: $0, ageBracket: ageBracket)) }
    }

    var latest: (session: SleepSession, score: SleepScore)? {
        guard let nightOf = selectedNightOf, let session = sessions.first(where: { $0.nightOf == nightOf }) ?? sessions.last else { return nil }
        return (session, SleepScoreEngine.score(for: session, ageBracket: ageBracket))
    }

    /// All days that have enough trailing history to produce a stress score,
    /// most recent first.
    var stressScores: [(day: HeartRateDay, score: StressScore)] {
        heartRateDays.compactMap { day in
            guard let score = StressScoreEngine.score(for: heartRateDays, at: day.date) else { return nil }
            return (day, score)
        }
        .sorted { $0.day.date > $1.day.date }
    }

    var selectedStress: (day: HeartRateDay, score: StressScore)? {
        let target = selectedHeartDate ?? heartRateDays.last?.date
        guard let target, let day = heartRateDays.first(where: { Calendar.current.isDate($0.date, inSameDayAs: target) }) else { return nil }
        guard let score = StressScoreEngine.score(for: heartRateDays, at: day.date) else { return nil }
        return (day, score)
    }

    var selectedHeartRateDay: HeartRateDay? {
        let target = selectedHeartDate ?? heartRateDays.last?.date
        guard let target else { return nil }
        return heartRateDays.first { Calendar.current.isDate($0.date, inSameDayAs: target) }
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
                    self.heartRateDays = result.heartRateDays.sorted { $0.date < $1.date }
                    self.selectedHeartDate = Self.bestDefaultDate(in: self.heartRateDays)
                    self.lastImportSource = result.sourceUsed
                    self.isImporting = false

                    // Auto-detect age bracket from the export's date-of-birth on the
                    // very first import only; never override an explicit user choice later.
                    if isFirstImport, let dob = result.dateOfBirth {
                        let years = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 30
                        self.setAgeBracket(AgeBracket.from(age: years))
                    }

                    // Don't re-suggest the file we just imported.
                    if let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate {
                        var settings = Store.shared.loadSettings()
                        settings.dismissedCandidatePath = url.path
                        settings.dismissedCandidateModDate = modDate
                        Store.shared.saveSettings(settings)
                    }
                    self.scanForCandidateExport()
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
