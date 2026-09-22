// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SleepTracker",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "SleepTrackerCore",
            path: "Sources/SleepTrackerCore"
        ),
        .executableTarget(
            name: "SleepTracker",
            dependencies: ["SleepTrackerCore"],
            path: "Sources/SleepTracker"
        ),
        .executableTarget(
            name: "SleepTrackerSelfTests",
            dependencies: ["SleepTrackerCore"],
            path: "Sources/SleepTrackerSelfTests"
        )
    ]
)
