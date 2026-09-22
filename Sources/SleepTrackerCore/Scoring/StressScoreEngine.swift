import Foundation

public struct StressScore: Codable {
    /// 0-100, higher means *more* stressed (this is a stress level, not a
    /// wellness score — unlike the sleep score, higher is not better here).
    public let level: Int
    public let label: String
    public let components: [ComponentScore]
    public let caveats: [String]
    public let baselineDaysUsed: Int
}

/// Deterministic, explainable stress-level estimate from heart-rate variability
/// (HRV, measured as SDNN) and resting heart rate (RHR) — no ML model, no
/// per-day AI call, recomputed the same way every time from the raw numbers.
///
/// Unlike the sleep score, this deliberately does *not* use fixed population
/// thresholds. HRV in particular varies enormously between individuals
/// (healthy adult SDNN can range roughly from ~20 ms to over 100 ms depending
/// on age, fitness and physiology), so an absolute cutoff would be meaningless
/// for most people. Instead this follows the standard approach used in HRV-based
/// readiness/stress research and consumer tools: compare each day to the
/// *person's own* trailing baseline and score the deviation.
///
/// Sources:
/// - Kim, H.G., Cheon, E.J., Bai, D.S., Lee, Y.H., Koo, B.H. (2018). "Stress and
///   Heart Rate Variability: A Meta-Analysis and Review of the Literature."
///   Psychiatry Investigation, 15(3), 235-245. → HRV (SDNN/RMSSD) is inversely
///   associated with physiological and perceived stress.
/// - Task Force of the European Society of Cardiology and the North American
///   Society of Pacing and Electrophysiology (1996). "Heart rate variability:
///   standards of measurement, physiological interpretation and clinical use."
///   Circulation, 93(5), 1043-1065. → defines SDNN and establishes that HRV
///   must be interpreted relative to the individual, not a population norm.
/// - Plews, D.J., Laursen, P.B., Stanley, J., Kilding, A.E., Buchheit, M. (2013).
///   "Training adaptation and heart rate variability in elite endurance
///   athletes: opening the door to effective monitoring." Sports Medicine,
///   43(9), 773-781. → basis for the rolling personal-baseline methodology
///   used by HRV-based readiness/stress tracking in general.
public enum StressScoreEngine {

    private static let minBaselineDays = 5
    private static let baselineWindowDays = 30
    private static let wHRV = 60.0
    private static let wRHR = 40.0

    public static func score(for days: [HeartRateDay], at targetDate: Date) -> StressScore? {
        let calendar = Calendar.current
        guard let today = days.first(where: { calendar.isDate($0.date, inSameDayAs: targetDate) }) else { return nil }

        let windowStart = calendar.date(byAdding: .day, value: -baselineWindowDays, to: targetDate) ?? targetDate
        let baselineDays = days.filter { $0.date >= windowStart && $0.date < calendar.startOfDay(for: targetDate) }

        let hrvBaseline = baselineDays.compactMap(\.hrvSDNN)
        let rhrBaseline = baselineDays.compactMap(\.restingBPM)

        var components: [ComponentScore] = []
        var caveats: [String] = []

        if let todayHRV = today.hrvSDNN, hrvBaseline.count >= minBaselineDays {
            let (mean, std) = meanAndStd(hrvBaseline)
            // Positive z = today's HRV is below baseline = more stress.
            let z = std > 0.5 ? (mean - todayHRV) / std : 0
            let fraction = clampedFraction(z)
            components.append(ComponentScore(
                name: "Variabilité cardiaque (HRV)",
                points: fraction * wHRV,
                maxPoints: wHRV,
                measuredText: String(format: "%.0f ms", todayHRV),
                idealText: String(format: "≥ ligne de base (%.0f ms)", mean),
                explanation: hrvExplanation(today: todayHRV, mean: mean, fraction: fraction)
            ))
        } else {
            caveats.append("Variabilité cardiaque (HRV) insuffisante pour établir une ligne de base personnelle (minimum \(minBaselineDays) jours).")
        }

        if let todayRHR = today.restingBPM, rhrBaseline.count >= minBaselineDays {
            let (mean, std) = meanAndStd(rhrBaseline)
            // Positive z = today's RHR is above baseline = more stress.
            let z = std > 0.5 ? (todayRHR - mean) / std : 0
            let fraction = clampedFraction(z)
            components.append(ComponentScore(
                name: "Fréquence cardiaque au repos",
                points: fraction * wRHR,
                maxPoints: wRHR,
                measuredText: String(format: "%.0f bpm", todayRHR),
                idealText: String(format: "≤ ligne de base (%.0f bpm)", mean),
                explanation: rhrExplanation(today: todayRHR, mean: mean, fraction: fraction)
            ))
        } else {
            caveats.append("Fréquence cardiaque au repos insuffisante pour établir une ligne de base personnelle (minimum \(minBaselineDays) jours).")
        }

        guard !components.isEmpty else { return nil }

        let earned = components.reduce(0.0) { $0 + $1.points }
        let possible = components.reduce(0.0) { $0 + $1.maxPoints }
        let level = Int((earned / possible * 100).rounded())

        return StressScore(
            level: level,
            label: label(for: level),
            components: components,
            caveats: caveats,
            baselineDaysUsed: max(hrvBaseline.count, rhrBaseline.count)
        )
    }

    /// Maps a z-score deviation from baseline to a 0...1 stress fraction.
    /// z ≤ 0 (today at or better than the personal baseline) → 0 stress
    /// contribution. z ≥ 2 (two baseline standard deviations worse) → 1 (max).
    private static func clampedFraction(_ z: Double) -> Double {
        min(max(z / 2, 0), 1)
    }

    private static func meanAndStd(_ values: [Double]) -> (mean: Double, std: Double) {
        let mean = values.reduce(0, +) / Double(values.count)
        guard values.count > 1 else { return (mean, 0) }
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count - 1)
        return (mean, variance.squareRoot())
    }

    private static func label(for level: Int) -> String {
        switch level {
        case 0..<25: return "Faible"
        case 25..<50: return "Modéré"
        case 50..<75: return "Élevé"
        default: return "Très élevé"
        }
    }

    private static func hrvExplanation(today: Double, mean: Double, fraction: Double) -> String {
        let t = String(format: "%.0f ms", today)
        let m = String(format: "%.0f ms", mean)
        if fraction <= 0.001 {
            return "HRV de \(t), à hauteur ou au-dessus de ta ligne de base (\(m)) : bon signe de récupération."
        } else if fraction >= 0.999 {
            return "HRV de \(t), nettement sous ta ligne de base (\(m)) : signe marqué de stress physiologique ou de fatigue."
        } else {
            return "HRV de \(t), en dessous de ta ligne de base (\(m))."
        }
    }

    private static func rhrExplanation(today: Double, mean: Double, fraction: Double) -> String {
        let t = String(format: "%.0f bpm", today)
        let m = String(format: "%.0f bpm", mean)
        if fraction <= 0.001 {
            return "Fréquence cardiaque au repos de \(t), à hauteur ou sous ta ligne de base (\(m)) : pas de signe d'élévation liée au stress."
        } else if fraction >= 0.999 {
            return "Fréquence cardiaque au repos de \(t), nettement au-dessus de ta ligne de base (\(m)) : signe possible de stress, de fatigue ou de surmenage."
        } else {
            return "Fréquence cardiaque au repos de \(t), au-dessus de ta ligne de base (\(m))."
        }
    }
}
