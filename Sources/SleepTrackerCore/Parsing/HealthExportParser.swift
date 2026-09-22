import Foundation

/// Streams an Apple Health `export.xml` file (SAX parsing, so multi-hundred-MB
/// exports don't need to be loaded into memory as a DOM) and pulls out every
/// `HKCategoryTypeIdentifierSleepAnalysis` record, plus the user's date of birth
/// from the `<Me .../>` element if present.
public final class HealthExportParser: NSObject, XMLParserDelegate {
    public private(set) var samples: [SleepSample] = []
    public private(set) var dateOfBirth: Date?

    public override init() { super.init() }

    private static let recordDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let dobFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    public enum ParseError: Error, LocalizedError {
        case cannotOpen
        case xmlError(String)

        public var errorDescription: String? {
            switch self {
            case .cannotOpen: return "Impossible d'ouvrir le fichier d'export."
            case .xmlError(let msg): return "Erreur de lecture du fichier XML : \(msg)"
            }
        }
    }

    /// Parses the export. `progress` is called periodically with the number of
    /// sleep records found so far (there is no reliable way to know the total
    /// ahead of time without a first pass over a potentially huge file).
    public func parse(fileAt url: URL, progress: ((Int) -> Void)? = nil) throws {
        guard let stream = InputStream(url: url) else { throw ParseError.cannotOpen }
        let parser = XMLParser(stream: stream)
        parser.delegate = self
        self.progressCallback = progress
        if !parser.parse() {
            let msg = parser.parserError?.localizedDescription ?? "inconnue"
            throw ParseError.xmlError(msg)
        }
    }

    private var progressCallback: ((Int) -> Void)?

    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "Record":
            guard attributeDict["type"] == "HKCategoryTypeIdentifierSleepAnalysis" else { return }
            guard let value = attributeDict["value"],
                  let startStr = attributeDict["startDate"],
                  let endStr = attributeDict["endDate"],
                  let start = Self.recordDateFormatter.date(from: startStr),
                  let end = Self.recordDateFormatter.date(from: endStr),
                  end > start else { return }
            guard let stage = Self.stage(for: value) else { return }
            let source = attributeDict["sourceName"] ?? "inconnue"
            samples.append(SleepSample(stage: stage, start: start, end: end, source: source))
            if samples.count % 500 == 0 { progressCallback?(samples.count) }
        case "Me":
            if let dobStr = attributeDict["HKCharacteristicTypeIdentifierDateOfBirth"],
               let dob = Self.dobFormatter.date(from: dobStr) {
                dateOfBirth = dob
            }
        default:
            break
        }
    }

    private static func stage(for hkValue: String) -> SleepSample.Stage? {
        switch hkValue {
        case "HKCategoryValueSleepAnalysisInBed": return .inBed
        case "HKCategoryValueSleepAnalysisAwake": return .awake
        case "HKCategoryValueSleepAnalysisAsleepCore": return .core
        case "HKCategoryValueSleepAnalysisAsleepDeep": return .deep
        case "HKCategoryValueSleepAnalysisAsleepREM": return .rem
        case "HKCategoryValueSleepAnalysisAsleep", "HKCategoryValueSleepAnalysisAsleepUnspecified":
            return .asleepUnspecified
        default: return nil
        }
    }
}
