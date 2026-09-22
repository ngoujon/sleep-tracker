import Foundation

/// Local cache of parsed sessions + settings, so the (potentially huge)
/// Health export only needs to be re-parsed when the user explicitly
/// re-imports it.
public final class Store {
    public static let shared = Store()

    private let fileURL: URL
    private let settingsURL: URL
    private let heartRateURL: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SleepTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("sessions.json")
        settingsURL = base.appendingPathComponent("settings.json")
        heartRateURL = base.appendingPathComponent("heartrate.json")
    }

    public struct Settings: Codable {
        public var ageBracket: AgeBracket = .adult
        public var lastImportedSource: String?
        public var lastImportDate: Date?
        public init() {}
    }

    public func loadSessions() -> [SleepSession] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([SleepSession].self, from: data)) ?? []
    }

    public func saveSessions(_ sessions: [SleepSession]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    public func loadHeartRateDays() -> [HeartRateDay] {
        guard let data = try? Data(contentsOf: heartRateURL) else { return [] }
        return (try? JSONDecoder().decode([HeartRateDay].self, from: data)) ?? []
    }

    public func saveHeartRateDays(_ days: [HeartRateDay]) {
        guard let data = try? JSONEncoder().encode(days) else { return }
        try? data.write(to: heartRateURL, options: .atomic)
    }

    public func loadSettings() -> Settings {
        guard let data = try? Data(contentsOf: settingsURL) else { return Settings() }
        return (try? JSONDecoder().decode(Settings.self, from: data)) ?? Settings()
    }

    public func saveSettings(_ settings: Settings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? data.write(to: settingsURL, options: .atomic)
    }
}
