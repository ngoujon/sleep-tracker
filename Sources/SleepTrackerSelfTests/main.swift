import Foundation
import SleepTrackerCore

// Hand-rolled test harness: the full Xcode.app (and its XCTest.framework) is
// not installed on this machine, only the Command Line Tools, so `swift test`
// can't run. This gives the same "run the logic, assert on the result"
// coverage as an XCTest target, just without the framework dependency.

var failures = 0
var ran = 0

func check(_ name: String, _ condition: @autoclosure () -> Bool) {
    ran += 1
    if condition() {
        print("  ok - \(name)")
    } else {
        failures += 1
        print("  FAIL - \(name)")
    }
}

func approx(_ a: Double, _ b: Double, tolerance: Double = 0.01) -> Bool {
    abs(a - b) <= tolerance
}

func date(_ hour: Int, _ minute: Int = 0, day: Int = 1) -> Date {
    var comps = DateComponents()
    comps.year = 2026; comps.month = 1; comps.day = day; comps.hour = hour; comps.minute = minute
    return Calendar.current.date(from: comps)!
}

func makeSession(
    inBedMinutes: Double?,
    asleepMinutes: Double,
    coreMinutes: Double,
    deepMinutes: Double,
    remMinutes: Double,
    unspecifiedMinutes: Double,
    awakeMinutes: Double,
    awakeningsCount: Int,
    continuityDataAvailable: Bool
) -> SleepSession {
    let start = Date(timeIntervalSince1970: 0)
    let end = start.addingTimeInterval(asleepMinutes * 60 + awakeMinutes * 60)
    return SleepSession(
        nightOf: start,
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
        continuityDataAvailable: continuityDataAvailable
    )
}

// MARK: - SleepScoreEngine

print("SleepScoreEngine")

do {
    let asleep = 480.0
    let session = makeSession(inBedMinutes: 495, asleepMinutes: asleep, coreMinutes: asleep * 0.58, deepMinutes: asleep * 0.18, remMinutes: asleep * 0.24, unspecifiedMinutes: 0, awakeMinutes: 15, awakeningsCount: 1, continuityDataAvailable: true)
    let score = SleepScoreEngine.score(for: session, ageBracket: .adult)
    check("excellent night scores >= 90 (got \(score.total))", score.total >= 90)
    check("excellent night has no caveats", score.caveats.isEmpty)
}

do {
    let asleep = 240.0
    let session = makeSession(inBedMinutes: 380, asleepMinutes: asleep, coreMinutes: asleep * 0.85, deepMinutes: asleep * 0.03, remMinutes: asleep * 0.10, unspecifiedMinutes: 0, awakeMinutes: 90, awakeningsCount: 6, continuityDataAvailable: true)
    let score = SleepScoreEngine.score(for: session, ageBracket: .adult)
    check("short fragmented night scores < 40 (got \(score.total))", score.total < 40)
}

do {
    let asleep = 420.0
    let session = makeSession(inBedMinutes: 450, asleepMinutes: asleep, coreMinutes: 0, deepMinutes: 0, remMinutes: 0, unspecifiedMinutes: asleep, awakeMinutes: 10, awakeningsCount: 1, continuityDataAvailable: true)
    check("no stage detail -> hasStageDetail is false", !session.hasStageDetail)
    let score = SleepScoreEngine.score(for: session, ageBracket: .adult)
    check("missing stage detail excludes architecture components", !score.components.contains { $0.name.contains("profond") || $0.name.contains("REM") })
    check("missing stage detail adds a caveat", score.caveats.contains { $0.contains("Détail des phases") })
    check("score still within 0...100", score.total >= 0 && score.total <= 100)
}

do {
    let asleep = 420.0
    let session = makeSession(inBedMinutes: nil, asleepMinutes: asleep, coreMinutes: asleep * 0.6, deepMinutes: asleep * 0.18, remMinutes: asleep * 0.22, unspecifiedMinutes: 0, awakeMinutes: 0, awakeningsCount: 0, continuityDataAvailable: false)
    let score = SleepScoreEngine.score(for: session, ageBracket: .adult)
    check("no continuity data excludes awakenings component", !score.components.contains { $0.name.contains("Réveils") })
    check("no continuity data adds a caveat", score.caveats.contains { $0.contains("Continuité") })
}

do {
    let onBound = makeSession(inBedMinutes: 460, asleepMinutes: 420, coreMinutes: 420 * 0.6, deepMinutes: 420 * 0.18, remMinutes: 420 * 0.22, unspecifiedMinutes: 0, awakeMinutes: 10, awakeningsCount: 1, continuityDataAvailable: true)
    let onScore = SleepScoreEngine.score(for: onBound, ageBracket: .adult)
    let durationComponent = onScore.components.first { $0.name == "Durée de sommeil" }!
    check("7h exactly gets full duration credit", approx(durationComponent.points, durationComponent.maxPoints))

    let tooShort = makeSession(inBedMinutes: 140, asleepMinutes: 120, coreMinutes: 120 * 0.6, deepMinutes: 120 * 0.18, remMinutes: 120 * 0.22, unspecifiedMinutes: 0, awakeMinutes: 10, awakeningsCount: 1, continuityDataAvailable: true)
    let shortScore = SleepScoreEngine.score(for: tooShort, ageBracket: .adult)
    let shortDuration = shortScore.components.first { $0.name == "Durée de sommeil" }!
    check("2h gets zero duration credit", approx(shortDuration.points, 0))
}

// MARK: - SessionBuilder

print("SessionBuilder")

do {
    let threeAM = date(3, day: 2)
    let samples: [SleepSample] = [
        SleepSample(stage: .core, start: date(23, day: 1), end: threeAM, source: "Watch"),
        SleepSample(stage: .awake, start: threeAM, end: threeAM.addingTimeInterval(8 * 60), source: "Watch"),
        SleepSample(stage: .deep, start: date(3, 8, day: 2), end: date(5, day: 2), source: "Watch"),
        SleepSample(stage: .rem, start: date(5, day: 2), end: date(7, day: 2), source: "Watch")
    ]
    let result = SessionBuilder.build(from: samples)
    check("one session built", result.sessions.count == 1)
    if let session = result.sessions.first {
        check("one interior awakening detected", session.awakeningsCount == 1)
        check("8 minutes of WASO", approx(session.awakeMinutes, 8))
        check("continuity data available", session.continuityDataAvailable)
        // 4h core (23:00-03:00) + 1h52 deep (03:08-05:00) + 2h rem (05:00-07:00) = 472 min
        // (the 8-minute awakening at 03:00 pushes the deep stage's start back).
        check("7h52 asleep total", approx(session.asleepMinutes, 472))
    }
}

do {
    let samples: [SleepSample] = [
        SleepSample(stage: .core, start: date(14, day: 1), end: date(14, 30, day: 1), source: "Watch")
    ]
    let result = SessionBuilder.build(from: samples)
    check("30-minute nap dropped, not treated as a night", result.sessions.isEmpty)
}

do {
    let watch: [SleepSample] = [
        SleepSample(stage: .core, start: date(23, day: 1), end: date(7, day: 2), source: "Watch")
    ]
    let phone: [SleepSample] = [
        SleepSample(stage: .asleepUnspecified, start: date(23, 30, day: 1), end: date(1, day: 2), source: "iPhone")
    ]
    let result = SessionBuilder.build(from: watch + phone)
    check("dominant source (Watch) selected", result.sourceUsed == "Watch")
    check("only one session (no double counting across sources)", result.sessions.count == 1)
}

do {
    let samples: [SleepSample] = [
        SleepSample(stage: .core, start: date(22, day: 1), end: date(23, day: 1), source: "Watch"),
        SleepSample(stage: .deep, start: date(1, day: 2), end: date(6, day: 2), source: "Watch")
    ]
    let result = SessionBuilder.build(from: samples)
    check("gap under 3h merged into a single session", result.sessions.count == 1)
}

// MARK: - HeartRateBuilder

print("HeartRateBuilder")

func dayDate(_ offset: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: offset, to: date(0, day: 1))!
}

do {
    let d0 = dayDate(0)
    let samples: [QuantitySample] = [
        QuantitySample(kind: .heartRate, value: 60, start: d0.addingTimeInterval(3600), end: d0.addingTimeInterval(3600), source: "Watch"),
        QuantitySample(kind: .heartRate, value: 80, start: d0.addingTimeInterval(7200), end: d0.addingTimeInterval(7200), source: "Watch"),
        QuantitySample(kind: .heartRate, value: 100, start: d0.addingTimeInterval(10800), end: d0.addingTimeInterval(10800), source: "Watch"),
        QuantitySample(kind: .restingHeartRate, value: 55, start: d0, end: d0, source: "Watch"),
        QuantitySample(kind: .hrvSDNN, value: 42, start: d0.addingTimeInterval(3600), end: d0.addingTimeInterval(3600), source: "Watch"),
        QuantitySample(kind: .respiratoryRate, value: 14, start: d0.addingTimeInterval(3600), end: d0.addingTimeInterval(3600), source: "Watch")
    ]
    let days = HeartRateBuilder.build(from: samples)
    check("one day built", days.count == 1)
    if let day = days.first {
        check("min bpm is 60", approx(day.minBPM ?? -1, 60))
        check("max bpm is 100", approx(day.maxBPM ?? -1, 100))
        check("avg bpm is 80", approx(day.avgBPM ?? -1, 80))
        check("resting bpm is 55", approx(day.restingBPM ?? -1, 55))
        check("hrv sdnn is 42", approx(day.hrvSDNN ?? -1, 42))
        check("respiratory rate is 14", approx(day.respiratoryRate ?? -1, 14))
    }
}

// MARK: - StressScoreEngine

print("StressScoreEngine")

func makeHeartDay(offset: Int, resting: Double?, hrv: Double?) -> HeartRateDay {
    HeartRateDay(date: dayDate(offset), minBPM: nil, maxBPM: nil, avgBPM: nil, restingBPM: resting, hrvSDNN: hrv, respiratoryRate: nil)
}

do {
    // Only 3 days of history before target -> below the 5-day minimum baseline.
    var days = (1...3).map { makeHeartDay(offset: -$0, resting: 55, hrv: 45) }
    days.append(makeHeartDay(offset: 0, resting: 55, hrv: 45))
    let score = StressScoreEngine.score(for: days, at: dayDate(0))
    check("insufficient baseline history returns nil", score == nil)
}

do {
    // Stable baseline (55 bpm resting, 45 ms HRV, zero variance), today matches exactly -> low stress.
    var days = (1...10).map { makeHeartDay(offset: -$0, resting: 55, hrv: 45) }
    days.append(makeHeartDay(offset: 0, resting: 55, hrv: 45))
    let score = StressScoreEngine.score(for: days, at: dayDate(0))
    check("stress score computed when baseline is sufficient", score != nil)
    if let score {
        check("today matching baseline exactly scores low stress (got \(score.level))", score.level <= 10)
        check("no caveats when both signals available", score.caveats.isEmpty)
        check("two components (HRV + RHR)", score.components.count == 2)
    }
}

do {
    // Baseline varies naturally (55±5 bpm, 45±5 ms), today is a clear outlier:
    // resting HR way up, HRV way down -> high stress.
    var days: [HeartRateDay] = []
    for i in 1...14 {
        let jitter = Double(i % 3) - 1 // -1, 0, 1
        days.append(makeHeartDay(offset: -i, resting: 55 + jitter * 3, hrv: 45 + jitter * 4))
    }
    days.append(makeHeartDay(offset: 0, resting: 75, hrv: 20))
    let score = StressScoreEngine.score(for: days, at: dayDate(0))
    check("stress score computed for outlier day", score != nil)
    if let score {
        check("elevated RHR + depressed HRV scores high stress (got \(score.level))", score.level >= 70)
    }
}

do {
    // Only HRV available (no resting HR data at all) -> still scores, with a caveat.
    var days = (1...10).map { i in
        HeartRateDay(date: dayDate(-i), minBPM: nil, maxBPM: nil, avgBPM: nil, restingBPM: nil, hrvSDNN: 45, respiratoryRate: nil)
    }
    days.append(HeartRateDay(date: dayDate(0), minBPM: nil, maxBPM: nil, avgBPM: nil, restingBPM: nil, hrvSDNN: 20, respiratoryRate: nil))
    let score = StressScoreEngine.score(for: days, at: dayDate(0))
    check("scores with only HRV available", score != nil)
    if let score {
        check("single component when only HRV available", score.components.count == 1)
        check("caveat mentions missing resting heart rate", score.caveats.contains { $0.contains("Fréquence cardiaque au repos") })
    }
}

print("")
print("\(ran - failures)/\(ran) checks passed")
if failures > 0 {
    exit(1)
}
