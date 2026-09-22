import Foundation

/// Looks for a Health export the user already has sitting around (e.g. just
/// AirDropped from the iPhone into Téléchargements, or saved from Mail/Fichiers),
/// so importing can be a one-click "oui, c'est bien ce fichier" instead of a
/// manual trip through a file picker.
///
/// This is a filesystem convenience, not a permission system: macOS has no
/// HealthKit-style "autoriser l'accès à Santé" prompt for a plain AppKit/SwiftUI
/// app (that API only exists for Mac Catalyst apps signed with a paid Apple
/// Developer HealthKit entitlement, which this build doesn't have). Scanning
/// well-known folders for a recent export is the closest practical substitute.
enum AutoImportScanner {
    struct Candidate: Equatable {
        let url: URL
        let modifiedAt: Date
    }

    /// Only surface files touched in the last month — an old export sitting in
    /// Downloads from ages ago is more likely clutter than something to import.
    private static let maxAge: TimeInterval = 30 * 24 * 3600

    static func scan() -> Candidate? {
        let fm = FileManager.default
        let searchDirs = [
            fm.urls(for: .downloadsDirectory, in: .userDomainMask).first,
            fm.urls(for: .desktopDirectory, in: .userDomainMask).first
        ].compactMap { $0 }

        let cutoff = Date().addingTimeInterval(-maxAge)
        var best: Candidate?

        for dir in searchDirs {
            guard let items = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in items {
                let ext = url.pathExtension.lowercased()
                guard ext == "zip" || ext == "xml" else { continue }
                let name = url.deletingPathExtension().lastPathComponent.lowercased()
                guard name.contains("export") || name.contains("santé") || name.contains("health") else { continue }
                guard let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                      modDate > cutoff else { continue }

                if best == nil || modDate > best!.modifiedAt {
                    best = Candidate(url: url, modifiedAt: modDate)
                }
            }
        }
        return best
    }
}
