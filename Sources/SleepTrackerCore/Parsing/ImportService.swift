import Foundation

/// Orchestrates a full import: unzip (if needed) → SAX parse → cluster into
/// nightly sessions → merge with whatever is already cached.
public enum ImportService {

    public struct ImportResult {
        public let sessions: [SleepSession]
        public let sourceUsed: String
        public let dateOfBirth: Date?
        public let newNightsCount: Int
    }

    public enum ImportError: Error, LocalizedError {
        case unsupportedFile
        case unzipFailed
        case exportXMLNotFound

        public var errorDescription: String? {
            switch self {
            case .unsupportedFile: return "Choisis le fichier export.xml ou l'archive export.zip exportée depuis l'app Santé."
            case .unzipFailed: return "Impossible de décompresser l'archive."
            case .exportXMLNotFound: return "export.xml introuvable dans l'archive."
            }
        }
    }

    public static func importHealthData(from url: URL, progress: ((Int) -> Void)? = nil) throws -> ImportResult {
        let xmlURL: URL
        var cleanupDir: URL?

        switch url.pathExtension.lowercased() {
        case "xml":
            xmlURL = url
        case "zip":
            let (extracted, dir) = try unzip(url)
            xmlURL = extracted
            cleanupDir = dir
        default:
            throw ImportError.unsupportedFile
        }

        defer {
            if let cleanupDir {
                try? FileManager.default.removeItem(at: cleanupDir)
            }
        }

        let parser = HealthExportParser()
        try parser.parse(fileAt: xmlURL, progress: progress)

        let built = SessionBuilder.build(from: parser.samples)

        let existing = Store.shared.loadSessions()
        var byNight = Dictionary(uniqueKeysWithValues: existing.map { ($0.nightOf, $0) })
        var newCount = 0
        for session in built.sessions {
            if byNight[session.nightOf] == nil { newCount += 1 }
            byNight[session.nightOf] = session
        }
        let merged = byNight.values.sorted { $0.nightOf < $1.nightOf }
        Store.shared.saveSessions(merged)

        var settings = Store.shared.loadSettings()
        settings.lastImportedSource = built.sourceUsed
        settings.lastImportDate = Date()
        Store.shared.saveSettings(settings)

        return ImportResult(sessions: merged, sourceUsed: built.sourceUsed, dateOfBirth: parser.dateOfBirth, newNightsCount: newCount)
    }

    private static func unzip(_ url: URL) throws -> (xml: URL, dir: URL) {
        let workDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", url.path, "-d", workDir.path]
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ImportError.unzipFailed }

        guard let xml = findExportXML(in: workDir) else { throw ImportError.exportXMLNotFound }
        return (xml, workDir)
    }

    private static func findExportXML(in dir: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else { return nil }
        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == "export.xml" {
            return fileURL
        }
        return nil
    }
}
