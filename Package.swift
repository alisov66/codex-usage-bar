// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexUsageBar",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "CodexUsageBar", targets: ["CodexUsageBar"])],
    targets: [
        .target(name: "UsageCore"),
        .executableTarget(name: "CodexUsageBar", dependencies: ["UsageCore"]),
        .testTarget(name: "UsageCoreTests", dependencies: ["UsageCore"])
    ]
)
