import Foundation

/// Turns the flat list of raw sleep-analysis samples parsed from a Health
/// export into one `SleepSession` per night.
///
/// Apple Health can contain overlapping records from several sources (iPhone,
/// Apple Watch, third-party apps) covering the same nights. Mixing them would
/// double-count sleep time, so we keep only the single source with the most
/// total sleep-analysis coverage and build sessions from that source alone.
public enum SessionBuilder {

    /// Two samples less than this far apart are considered part of the same
    /// sleep episode (covers brief tracking gaps, e.g. the watch losing signal).
    private static let mergeGap: TimeInterval = 3 * 3600

    /// Episodes with less total asleep time than this are treated as a nap,
    /// not a night's sleep, and dropped.
    private static let minAsleepMinutesForSession: Double = 60

    /// An awake episode shorter than this doesn't count as a countable
    /// "awakening" per the Ohayon et al. 2017 NSF consensus definition.
    private static let awakeningMinDuration: TimeInterval = 5 * 60

    public struct Result {
        public let sessions: [SleepSession]
        public let sourceUsed: String
    }

    public static func build(from samples: [SleepSample]) -> Result {
        guard !samples.isEmpty else { return Result(sessions: [], sourceUsed: "") }

        let bySource = Dictionary(grouping: samples, by: \.source)
        let dominantSource = bySource.max { a, b in
            totalAsleepDuration(a.value) < totalAsleepDuration(b.value)
        }!.key

        let sourceSamples = (bySource[dominantSource] ?? []).sorted { $0.start < $1.start }

        var clusters: [[SleepSample]] = []
        var current: [SleepSample] = []
        var currentEnd: Date?

        for sample in sourceSamples {
            if let end = currentEnd, sample.start.timeIntervalSince(end) > mergeGap {
                clusters.append(current)
                current = []
            }
            current.append(sample)
            currentEnd = max(currentEnd ?? sample.end, sample.end)
        }
        if !current.isEmpty { clusters.append(current) }

        var sessions = clusters.compactMap(session(from:))

        // If several sessions land on the same calendar night (e.g. a long
        // afternoon nap plus the real night), keep only the longest one.
        var byNight: [Date: SleepSession] = [:]
        for s in sessions {
            if let existing = byNight[s.nightOf], existing.asleepMinutes >= s.asleepMinutes {
                continue
            }
            byNight[s.nightOf] = s
        }
        sessions = byNight.values.sorted { $0.nightOf < $1.nightOf }

        return Result(sessions: sessions, sourceUsed: dominantSource)
    }

    private static func totalAsleepDuration(_ samples: [SleepSample]) -> TimeInterval {
        samples
            .filter { [.core, .deep, .rem, .asleepUnspecified].contains($0.stage) }
            .reduce(0) { $0 + $1.duration }
    }

    private static func session(from cluster: [SleepSample]) -> SleepSession? {
        let asleepStages: Set<SleepSample.Stage> = [.core, .deep, .rem, .asleepUnspecified]
        let asleepSamples = cluster.filter { asleepStages.contains($0.stage) }
        guard !asleepSamples.isEmpty else { return nil }

        let asleepMinutes = asleepSamples.reduce(0.0) { $0 + $1.duration / 60 }
        guard asleepMinutes >= minAsleepMinutesForSession else { return nil }

        let coreMinutes = sumMinutes(cluster, stage: .core)
        let deepMinutes = sumMinutes(cluster, stage: .deep)
        let remMinutes = sumMinutes(cluster, stage: .rem)
        let unspecifiedMinutes = sumMinutes(cluster, stage: .asleepUnspecified)

        let inBedSamples = cluster.filter { $0.stage == .inBed }
        let inBedMinutes: Double? = inBedSamples.isEmpty ? nil : inBedSamples.reduce(0.0) { $0 + $1.duration / 60 }

        let firstAsleep = asleepSamples.map(\.start).min()!
        let lastAsleep = asleepSamples.map(\.end).max()!

        let awakeSamples = cluster
            .filter { $0.stage == .awake }
            .compactMap { sample -> (Date, Date)? in
                let clampedStart = max(sample.start, firstAsleep)
                let clampedEnd = min(sample.end, lastAsleep)
                return clampedEnd > clampedStart ? (clampedStart, clampedEnd) : nil
            }
            .sorted { $0.0 < $1.0 }

        let mergedAwake = mergeIntervals(awakeSamples)
        let awakeMinutes = mergedAwake.reduce(0.0) { $0 + $1.1.timeIntervalSince($1.0) / 60 }
        let awakeningsCount = mergedAwake.filter { $0.1.timeIntervalSince($0.0) >= awakeningMinDuration }.count

        let continuityAvailable = !mergedAwake.isEmpty || (inBedMinutes ?? 0) > asleepMinutes + 5

        let start = cluster.map(\.start).min()!
        let end = cluster.map(\.end).max()!

        let calendar = Calendar.current
        let nightOf = calendar.startOfDay(for: end)

        return SleepSession(
            nightOf: nightOf,
            start: start,
            end: end,
            inBedMinutes: inBedMinutes,
            asleepMinutes: asleepMinutes,
            coreMinutes: coreMinutes,
            deepMinutes: deepMinutes,
            remMinutes: remMinutes,
            unspecifiedMinutes: unspecifiedMinutes,
            awakeMinutes: awakeMinutes,
            awakeningsCount: awakeningsCount,
            continuityDataAvailable: continuityAvailable
        )
    }

    private static func sumMinutes(_ cluster: [SleepSample], stage: SleepSample.Stage) -> Double {
        cluster.filter { $0.stage == stage }.reduce(0.0) { $0 + $1.duration / 60 }
    }

    private static func mergeIntervals(_ intervals: [(Date, Date)]) -> [(Date, Date)] {
        guard !intervals.isEmpty else { return [] }
        var result: [(Date, Date)] = [intervals[0]]
        for interval in intervals.dropFirst() {
            let last = result[result.count - 1]
            if interval.0 <= last.1 {
                result[result.count - 1] = (last.0, max(last.1, interval.1))
            } else {
                result.append(interval)
            }
        }
        return result
    }
}
