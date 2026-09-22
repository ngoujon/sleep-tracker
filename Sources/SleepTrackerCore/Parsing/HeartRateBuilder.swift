import Foundation

/// Aggregates raw heart-rate/HRV/respiratory quantity samples into one
/// `HeartRateDay` per calendar day.
///
/// Unlike `SessionBuilder` for sleep, this does not restrict itself to a
/// single dominant source: overlapping continuous heart-rate samples from
/// several sources (e.g. iPhone + Watch) only bias a daily average slightly,
/// whereas the same overlap for sleep stages would double-count sleep
/// duration outright. That's a deliberate simplification for this dashboard,
/// not a precision instrument.
public enum HeartRateBuilder {
    public static func build(from samples: [QuantitySample]) -> [HeartRateDay] {
        guard !samples.isEmpty else { return [] }
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.start) }

        return byDay.map { day, daySamples in
            let hr = daySamples.filter { $0.kind == .heartRate }.map(\.value)
            let resting = daySamples.filter { $0.kind == .restingHeartRate }.map(\.value)
            let hrv = daySamples.filter { $0.kind == .hrvSDNN }.map(\.value)
            let resp = daySamples.filter { $0.kind == .respiratoryRate }.map(\.value)

            return HeartRateDay(
                date: day,
                minBPM: hr.min(),
                maxBPM: hr.max(),
                avgBPM: average(hr),
                restingBPM: average(resting),
                hrvSDNN: average(hrv),
                respiratoryRate: average(resp)
            )
        }
        .sorted { $0.date < $1.date }
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
