import Foundation

/// Raw sleep-analysis sample as found in an Apple Health export (one <Record> element).
public struct SleepSample {
    public enum Stage: String {
        case inBed
        case awake
        case core          // light sleep (N1+N2), Apple's "AsleepCore"
        case deep          // N3 / slow-wave sleep, Apple's "AsleepDeep"
        case rem           // REM sleep, Apple's "AsleepREM"
        case asleepUnspecified // pre-watchOS9 devices / iPhone-only estimation, no stage detail
    }

    public let stage: Stage
    public let start: Date
    public let end: Date
    public let source: String

    public init(stage: Stage, start: Date, end: Date, source: String) {
        self.stage = stage
        self.start = start
        self.end = end
        self.source = source
    }

    public var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// Age brackets used by the NSF sleep-quality consensus panel (Ohayon et al. 2017)
/// and the NSF sleep-duration report (Hirshkowitz et al. 2015). Thresholds in
/// `SleepScoreEngine` are keyed off this bracket.
public enum AgeBracket: String, Codable, CaseIterable, Identifiable {
    case youngAdult   // 18-25
    case adult        // 26-64
    case olderAdult   // 65+

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .youngAdult: return "18–25 ans"
        case .adult: return "26–64 ans"
        case .olderAdult: return "65 ans et plus"
        }
    }

    public static func from(age: Int) -> AgeBracket {
        switch age {
        case ..<26: return .youngAdult
        case 26..<65: return .adult
        default: return .olderAdult
        }
    }
}

/// One night of sleep, built by clustering raw samples (see `SessionBuilder`).
public struct SleepSession: Codable, Identifiable {
    public var id: String { nightOf.formatted(.iso8601.year().month().day()) + "-" + start.ISO8601Format() }

    /// The calendar day this session is attributed to (the day the user woke up).
    public let nightOf: Date

    public let start: Date
    public let end: Date

    public let inBedMinutes: Double?      // nil if the source never logs an InBed bracket
    public let asleepMinutes: Double
    public let coreMinutes: Double
    public let deepMinutes: Double
    public let remMinutes: Double
    public let unspecifiedMinutes: Double // asleep time with no stage detail available
    public let awakeMinutes: Double       // time awake *inside* the session (after first sleep, before last)
    public let awakeningsCount: Int       // number of distinct awake episodes >= 5 min inside the session

    /// Whether interior wake episodes could reliably be detected for this session.
    public let continuityDataAvailable: Bool

    public init(nightOf: Date, start: Date, end: Date, inBedMinutes: Double?, asleepMinutes: Double, coreMinutes: Double, deepMinutes: Double, remMinutes: Double, unspecifiedMinutes: Double, awakeMinutes: Double, awakeningsCount: Int, continuityDataAvailable: Bool) {
        self.nightOf = nightOf
        self.start = start
        self.end = end
        self.inBedMinutes = inBedMinutes
        self.asleepMinutes = asleepMinutes
        self.coreMinutes = coreMinutes
        self.deepMinutes = deepMinutes
        self.remMinutes = remMinutes
        self.unspecifiedMinutes = unspecifiedMinutes
        self.awakeMinutes = awakeMinutes
        self.awakeningsCount = awakeningsCount
        self.continuityDataAvailable = continuityDataAvailable
    }

    /// Whether stage detail (core/deep/rem) was available for this session at all.
    public var hasStageDetail: Bool { unspecifiedMinutes < asleepMinutes * 0.5 }

    public var totalMinutesInBedOrSpan: Double {
        inBedMinutes ?? (end.timeIntervalSince(start) / 60)
    }
}
