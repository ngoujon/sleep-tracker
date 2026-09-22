import Foundation

/// A single weighted ingredient of the overall sleep score.
public struct ComponentScore: Codable, Identifiable {
    public var id: String { name }
    public let name: String
    public let points: Double
    public let maxPoints: Double
    public let measuredText: String
    public let idealText: String
    public let explanation: String
}

public struct SleepScore: Codable {
    public let total: Int
    public let label: String
    public let components: [ComponentScore]
    public let caveats: [String]
}

/// Deterministic sleep-score calculator. No machine learning, no per-night AI
/// call: every number below is a fixed threshold taken from published sleep
/// research, and the score is a plain weighted sum recomputed the same way
/// every time from the raw Apple Health sleep-stage data.
///
/// Sources:
/// - Ohayon M, et al. "National Sleep Foundation's sleep quality
///   recommendations: first report." Sleep Health 3 (2017) 6-19.
///   → thresholds for sleep efficiency, wake after sleep onset (WASO),
///   number of awakenings ≥5 min, REM % and N3 (deep) % of total sleep time,
///   for the "young adult" (18-25), "adult" (26-64) and "older adult" (65+)
///   panels.
/// - Hirshkowitz M, et al. "National Sleep Foundation's sleep time duration
///   recommendations: methodology and results summary." Sleep Health (2015).
///   → recommended / may-be-appropriate / not-recommended sleep duration
///   bands by age.
public enum SleepScoreEngine {

    // MARK: - Weights (points out of 100 when all data is available)

    private static let wDuration = 30.0
    private static let wEfficiency = 20.0
    private static let wWASO = 10.0
    private static let wAwakenings = 10.0
    private static let wDeep = 15.0
    private static let wREM = 15.0

    // MARK: - Threshold tables

    private struct DurationBand {
        let zeroLow, oneLow, oneHigh, zeroHigh: Double // hours
    }

    private static func durationBand(for bracket: AgeBracket) -> DurationBand {
        switch bracket {
        case .youngAdult: return DurationBand(zeroLow: 5, oneLow: 7, oneHigh: 9, zeroHigh: 12)
        case .adult: return DurationBand(zeroLow: 5, oneLow: 7, oneHigh: 9, zeroHigh: 11)
        case .olderAdult: return DurationBand(zeroLow: 4, oneLow: 7, oneHigh: 8, zeroHigh: 10)
        }
    }

    /// (poorAt, goodAt) sleep efficiency in %, monotonic increasing.
    private static func efficiencyThresholds(for bracket: AgeBracket) -> (poor: Double, good: Double) {
        switch bracket {
        case .youngAdult: return (64, 85)
        case .adult, .olderAdult: return (74, 85)
        }
    }

    /// (goodMax, poorMin) WASO in minutes, monotonic decreasing (less is better).
    private static func wasoThresholds(for bracket: AgeBracket) -> (good: Double, poor: Double) {
        switch bracket {
        case .youngAdult, .adult: return (20, 41)
        case .olderAdult: return (20, 51)
        }
    }

    /// (goodMax, poorMin) count of awakenings ≥5 min, monotonic decreasing.
    private static func awakeningsThresholds(for bracket: AgeBracket) -> (good: Double, poor: Double) {
        switch bracket {
        case .youngAdult, .adult: return (1, 4)
        case .olderAdult: return (2, 4)
        }
    }

    /// REM % of total sleep time — true band (both too little and too much are penalised).
    /// Good band (21-30%) and poor-high (≥41%) are the panel's voted values; the
    /// poor-low bound is not voted by the panel and is a conservative extrapolation
    /// (documented here, not presented as consensus) so that implausibly low REM
    /// readings still pull the score down instead of scoring as neutral/unknown.
    private static let remGoodLow = 21.0, remGoodHigh = 30.0, remPoorLow = 8.0, remPoorHigh = 41.0

    /// Deep (N3) % of total sleep time — monotonic increasing to a plateau.
    /// 16-20% is the panel's voted "good" band for adults; below 5% is voted "poor".
    /// The panel did not vote an upper poor-bound for adults, so above 20% the
    /// score simply stays at its maximum rather than inventing a penalty.
    private static let deepPoorLow = 5.0, deepGoodLow = 16.0

    // MARK: - Public API

    public static func score(for session: SleepSession, ageBracket: AgeBracket) -> SleepScore {
        var components: [ComponentScore] = []
        var caveats: [String] = []

        // Duration
        let hours = session.asleepMinutes / 60
        let band = durationBand(for: ageBracket)
        let durationFraction = bandFraction(hours, zeroLow: band.zeroLow, oneLow: band.oneLow, oneHigh: band.oneHigh, zeroHigh: band.zeroHigh)
        components.append(ComponentScore(
            name: "Durée de sommeil",
            points: durationFraction * wDuration,
            maxPoints: wDuration,
            measuredText: formatHours(hours),
            idealText: "\(Int(band.oneLow))–\(Int(band.oneHigh)) h",
            explanation: durationExplanation(hours: hours, band: band, fraction: durationFraction)
        ))

        // Efficiency
        let efficiency = efficiencyPercent(for: session)
        if let efficiency {
            let (poor, good) = efficiencyThresholds(for: ageBracket)
            let fraction = increasingFraction(efficiency, poorAt: poor, goodAt: good)
            components.append(ComponentScore(
                name: "Efficacité du sommeil",
                points: fraction * wEfficiency,
                maxPoints: wEfficiency,
                measuredText: String(format: "%.0f %%", efficiency),
                idealText: "≥ \(Int(good)) %",
                explanation: efficiencyExplanation(efficiency: efficiency, good: good, poor: poor, fraction: fraction)
            ))
        } else {
            caveats.append("Efficacité du sommeil non calculée (pas de plage \u{201c}au lit\u{201d} dans les données).")
        }

        // Continuity: WASO + awakenings
        if session.continuityDataAvailable {
            let (wasoGood, wasoPoor) = wasoThresholds(for: ageBracket)
            let wasoFraction = decreasingFraction(session.awakeMinutes, goodAt: wasoGood, poorAt: wasoPoor)
            components.append(ComponentScore(
                name: "Réveils nocturnes (durée)",
                points: wasoFraction * wWASO,
                maxPoints: wWASO,
                measuredText: formatMinutes(session.awakeMinutes),
                idealText: "≤ \(Int(wasoGood)) min",
                explanation: wasoExplanation(minutes: session.awakeMinutes, good: wasoGood, poor: wasoPoor, fraction: wasoFraction)
            ))

            let (awkGood, awkPoor) = awakeningsThresholds(for: ageBracket)
            let awkFraction = decreasingFraction(Double(session.awakeningsCount), goodAt: awkGood, poorAt: awkPoor)
            components.append(ComponentScore(
                name: "Nombre de réveils",
                points: awkFraction * wAwakenings,
                maxPoints: wAwakenings,
                measuredText: "\(session.awakeningsCount)",
                idealText: "≤ \(Int(awkGood))",
                explanation: awakeningsExplanation(count: session.awakeningsCount, good: Int(awkGood), fraction: awkFraction)
            ))
        } else {
            caveats.append("Continuité du sommeil non évaluée (la source de données ne journalise pas les réveils).")
        }

        // Architecture: deep + REM
        if session.hasStageDetail {
            let deepPct = 100 * session.deepMinutes / session.asleepMinutes
            let remPct = 100 * session.remMinutes / session.asleepMinutes

            let deepFraction = increasingFraction(deepPct, poorAt: deepPoorLow, goodAt: deepGoodLow)
            components.append(ComponentScore(
                name: "Sommeil profond",
                points: deepFraction * wDeep,
                maxPoints: wDeep,
                measuredText: String(format: "%.0f %% (%@)", deepPct, formatMinutes(session.deepMinutes)),
                idealText: "16–20 %",
                explanation: deepExplanation(pct: deepPct, fraction: deepFraction)
            ))

            let remFraction = bandFraction(remPct, zeroLow: remPoorLow, oneLow: remGoodLow, oneHigh: remGoodHigh, zeroHigh: remPoorHigh)
            components.append(ComponentScore(
                name: "Sommeil paradoxal (REM)",
                points: remFraction * wREM,
                maxPoints: wREM,
                measuredText: String(format: "%.0f %% (%@)", remPct, formatMinutes(session.remMinutes)),
                idealText: "21–30 %",
                explanation: remExplanation(pct: remPct, fraction: remFraction)
            ))
        } else {
            caveats.append("Détail des phases (léger/profond/REM) indisponible pour cette nuit — score basé sur la durée et l'efficacité uniquement.")
        }

        let earned = components.reduce(0.0) { $0 + $1.points }
        let possible = components.reduce(0.0) { $0 + $1.maxPoints }
        let total = possible > 0 ? Int((earned / possible * 100).rounded()) : 0

        return SleepScore(total: total, label: label(for: total), components: components, caveats: caveats)
    }

    // MARK: - Efficiency helper

    private static func efficiencyPercent(for session: SleepSession) -> Double? {
        guard let inBed = session.inBedMinutes, inBed > 0 else { return nil }
        return min(100, 100 * session.asleepMinutes / inBed)
    }

    // MARK: - Curve shapes

    /// Trapezoid: 0 below zeroLow, ramps to 1 at oneLow, plateau at 1 until
    /// oneHigh, ramps back down to 0 at zeroHigh.
    private static func bandFraction(_ v: Double, zeroLow: Double, oneLow: Double, oneHigh: Double, zeroHigh: Double) -> Double {
        if v <= zeroLow || v >= zeroHigh { return 0 }
        if v < oneLow { return (v - zeroLow) / (oneLow - zeroLow) }
        if v <= oneHigh { return 1 }
        return (zeroHigh - v) / (zeroHigh - oneHigh)
    }

    /// 0 at/below poorAt, ramps linearly to 1 at/above goodAt.
    private static func increasingFraction(_ v: Double, poorAt: Double, goodAt: Double) -> Double {
        if v <= poorAt { return 0 }
        if v >= goodAt { return 1 }
        return (v - poorAt) / (goodAt - poorAt)
    }

    /// 1 at/below goodAt, ramps linearly down to 0 at/above poorAt.
    private static func decreasingFraction(_ v: Double, goodAt: Double, poorAt: Double) -> Double {
        if v <= goodAt { return 1 }
        if v >= poorAt { return 0 }
        return (poorAt - v) / (poorAt - goodAt)
    }

    private static func label(for total: Int) -> String {
        switch total {
        case 90...: return "Excellent"
        case 80..<90: return "Très bon"
        case 70..<80: return "Bon"
        case 55..<70: return "Moyen"
        case 40..<55: return "Insuffisant"
        default: return "Mauvais"
        }
    }

    // MARK: - Formatting

    private static func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return "\(h) h \(String(format: "%02d", m))"
    }

    private static func formatMinutes(_ minutes: Double) -> String {
        if minutes < 60 { return "\(Int(minutes.rounded())) min" }
        let h = Int(minutes / 60)
        let m = Int(minutes.truncatingRemainder(dividingBy: 60))
        return "\(h) h \(String(format: "%02d", m))"
    }

    // MARK: - Explanations (deterministic templates, not generated text)

    private static func durationExplanation(hours: Double, band: DurationBand, fraction: Double) -> String {
        let ideal = "\(Int(band.oneLow))–\(Int(band.oneHigh)) h"
        if fraction >= 0.999 {
            return "\(formatHours(hours)) de sommeil, dans la fourchette recommandée (\(ideal))."
        } else if hours < band.oneLow {
            return "\(formatHours(hours)) de sommeil, en dessous de la fourchette recommandée (\(ideal)) : dette de sommeil probable."
        } else {
            return "\(formatHours(hours)) de sommeil, au-dessus de la fourchette recommandée (\(ideal))."
        }
    }

    private static func efficiencyExplanation(efficiency: Double, good: Double, poor: Double, fraction: Double) -> String {
        let pct = String(format: "%.0f %%", efficiency)
        if fraction >= 0.999 {
            return "Efficacité de \(pct) (temps endormi / temps au lit) : excellente, au-dessus du seuil de \(Int(good)) % retenu par le panel NSF."
        } else if fraction <= 0.001 {
            return "Efficacité de \(pct), sous le seuil de \(Int(poor)) % : nuit très fragmentée."
        } else {
            return "Efficacité de \(pct), en dessous du seuil de bonne qualité (\(Int(good)) %)."
        }
    }

    private static func wasoExplanation(minutes: Double, good: Double, poor: Double, fraction: Double) -> String {
        let m = formatMinutes(minutes)
        if fraction >= 0.999 {
            return "\(m) éveillé(e) pendant la nuit, sous le seuil de bonne qualité (\(Int(good)) min)."
        } else if fraction <= 0.001 {
            return "\(m) éveillé(e) pendant la nuit, au-delà du seuil de \(Int(poor)) min associé à un sommeil fragmenté."
        } else {
            return "\(m) éveillé(e) pendant la nuit, au-dessus du seuil idéal (\(Int(good)) min)."
        }
    }

    private static func awakeningsExplanation(count: Int, good: Int, fraction: Double) -> String {
        if fraction >= 0.999 {
            return "\(count) réveil(s) de plus de 5 min, conforme à un sommeil continu."
        } else if fraction <= 0.001 {
            return "\(count) réveils de plus de 5 min : sommeil nettement fragmenté."
        } else {
            return "\(count) réveils de plus de 5 min, au-dessus du repère de \(good)."
        }
    }

    private static func deepExplanation(pct: Double, fraction: Double) -> String {
        let p = String(format: "%.0f %%", pct)
        if fraction >= 0.999 {
            return "Sommeil profond \(p) du temps de sommeil, dans/au-dessus de la fourchette de référence (16–20 %) : bonne récupération physique."
        } else if pct <= deepPoorLow {
            return "Sommeil profond \(p), très faible (repère bas : 5 %) : récupération physique probablement insuffisante."
        } else {
            return "Sommeil profond \(p), sous la fourchette de référence (16–20 %)."
        }
    }

    private static func remExplanation(pct: Double, fraction: Double) -> String {
        let p = String(format: "%.0f %%", pct)
        if fraction >= 0.999 {
            return "Sommeil paradoxal (REM) \(p), dans la fourchette de référence (21–30 %) : bonne récupération cognitive."
        } else if pct >= remGoodHigh {
            return "Sommeil paradoxal (REM) \(p), au-dessus de la fourchette de référence (21–30 %)."
        } else {
            return "Sommeil paradoxal (REM) \(p), sous la fourchette de référence (21–30 %)."
        }
    }
}
