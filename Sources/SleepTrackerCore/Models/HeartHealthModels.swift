import Foundation

/// Raw numeric sample from the Health export for anything in the
/// heart-rate/HRV family (as opposed to the category-based sleep records).
public struct QuantitySample {
    public enum Kind {
        case heartRate          // bpm, continuous
        case restingHeartRate   // bpm, ~daily
        case hrvSDNN            // ms, HKQuantityTypeIdentifierHeartRateVariabilitySDNN
        case respiratoryRate    // breaths/min
    }

    public let kind: Kind
    public let value: Double
    public let start: Date
    public let end: Date
    public let source: String

    public init(kind: Kind, value: Double, start: Date, end: Date, source: String) {
        self.kind = kind
        self.value = value
        self.start = start
        self.end = end
        self.source = source
    }
}

/// One calendar day's worth of heart-rate-family data, aggregated from
/// whatever quantity samples exist for that day (see `HeartRateBuilder`).
public struct HeartRateDay: Codable, Identifiable {
    public var id: Date { date }

    public let date: Date
    public let minBPM: Double?
    public let maxBPM: Double?
    public let avgBPM: Double?
    public let restingBPM: Double?
    public let hrvSDNN: Double?          // ms
    public let respiratoryRate: Double?  // breaths/min

    public init(date: Date, minBPM: Double?, maxBPM: Double?, avgBPM: Double?, restingBPM: Double?, hrvSDNN: Double?, respiratoryRate: Double?) {
        self.date = date
        self.minBPM = minBPM
        self.maxBPM = maxBPM
        self.avgBPM = avgBPM
        self.restingBPM = restingBPM
        self.hrvSDNN = hrvSDNN
        self.respiratoryRate = respiratoryRate
    }
}
